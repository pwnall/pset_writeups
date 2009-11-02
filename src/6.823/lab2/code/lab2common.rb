#!/usr/bin/env ruby
#
# Author:: Victor Costan
# Copyright:: none
# License:: Public Domain


def bench_cases_fix_names(dir_name = 'accesses')
  files = Dir.glob("6.823/lab2/data/#{dir_name}/*")
  
  files.each_with_index do |file, i|
    ['.out', '.o'].each do |suffix|
      len = suffix.length
      next unless file[-len, len] == suffix
      File.rename file, file[0...-len]
      files[i] = file[0...-len]
    end
  end  
end

def bench_cases
  files = Dir.glob('6.823/lab2/data/accesses/*')  
  
  names = files.map { |file| File.basename(file) }.
                map { |file| file[0...file.index('_base')] }
  Hash[*names.zip(files).flatten]
end

def bench_values(cases, base_dir = 'original')  
  {}.tap do |values|
    cases.each do |name, file|
      # total_reads, total_writes, aligned_reads, aligned_writes
      numbers = File.read(file.gsub('/original/', "/#{base_dir}/")).split(',').
                     select { |token| !token.empty? }.map { |token| token.to_i }
      values[name] = numbers
    end
  end
end
