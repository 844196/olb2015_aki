require 'net/https'
require 'nokogiri'
require 'time'

module NicovideoAPIWrapper extend self
  @endpoint = 'watch.live.nicovideo.jp'

  def login(mail, password)
    https = Net::HTTP.new('secure.nicovideo.jp', 443)
    https.use_ssl = true
    https.verify_mode = OpenSSL::SSL::VERIFY_NONE
    response = https.start do |https|
      https.post('/secure/login?site=niconico', "mail=#{mail}&password=#{password}")
    end

    user_session = nil
    response.get_fields('set-cookie').each do |cookie|
      cookie.split('; ').each do |param|
        pair = param.split('=')
        if pair[0] == 'user_session'
          user_session = pair[1] unless pair[1] == 'deleted'
          break
        end
      end
      break unless user_session.nil?
    end
    user_session
  end

  def playerstatus(lv, user_session)
    url = Net::HTTP.new(@endpoint)
    res = url.get("/api/getplayerstatus?v=#{lv}", {'Cookie' => "user_session=#{user_session}"})
    xml = Nokogiri::XML(res.body)

    {
      user: xml.xpath('//user/user_id').text,
      addr: xml.xpath('//ms//addr').text,
      port: xml.xpath('//ms//port').text.to_i,
      thread: xml.xpath('//ms//thread').text
    }
  end

  def waybackkey(thread, user_session)
    url = Net::HTTP.new(@endpoint)
    res = url.get("/api/getwaybackkey?thread=#{thread}", {'Cookie' => "user_session=#{user_session}"})
    res.body[/waybackkey=(.+)/, 1]
  end
end

lv       = ARGV[0]
username = ARGV[1]
password = ARGV[2]

user_session = NicovideoAPIWrapper::login(username, password)
playerstatus = NicovideoAPIWrapper::playerstatus(lv, user_session)
waybackkey = NicovideoAPIWrapper::waybackkey(playerstatus[:thread], user_session)

data = {
  thread: playerstatus[:thread],
  version: 20061206,
  res_from: -1000,
  waybackkey: waybackkey,
  user_id: playerstatus[:user]
}

TCPSocket.open(playerstatus[:addr], playerstatus[:port]) do |socket|
  req = "<thread #{data.map {|k,v| "#{k}=\"#{v}\"" }.join(' ')}/>\0"
  socket.write(req)

  loop do
    stream = socket.gets("\0")
    xml = Nokogiri::XML(stream)

    next if xml.xpath('//chat').empty?
    break if xml.text == '/disconnect' && xml.xpath('/chat').attr('premium').text == '2'

    h = xml.xpath('/chat').first.attributes.map{|k,v| [k.to_sym,v.text] }.to_h
    h[:comment] = xml.text.gsub(/[\r\n]/, '')
    h[:premium] = 0 if h[:premium].nil?
    h[:date] = Time.at(h[:date].to_i)

    puts [h[:no], h[:date], h[:premium], h[:mail], h[:user_id], h[:comment]].join("\t")
  end
end
