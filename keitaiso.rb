require 'natto'

a = []
open('olb2015.tsv') do |file|
  while l =file.gets
    array = l.chomp.split("\t")
    a.push(array[-1])
  end
end

a.uniq!.sort_by! {|item| item.to_s }
a = a.compact.delete_if(&:empty?)

nm = Natto::MeCab.new

result = {}
a.each do |comment|
  nm.parse(comment) do |n|
    result[n.surface] = result[n.surface] ? result[n.surface] + 1 : 1
  end
end

h = result.to_h
h.delete_if {|k,v| k.size < 2 || k =~ /^[ぁ-ゞ]{,2}$/ }.each do |k,v|
  puts "#{v}\t#{k}"
end
