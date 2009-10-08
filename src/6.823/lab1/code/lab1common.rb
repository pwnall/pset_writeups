#!/usr/bin/env ruby
#
# Author:: Victor Costan
# Copyright:: none
# License:: Public Domain


def bench_cases_fix_names(dir_name = 'original')
  files = Dir.glob("6.823/lab1/data/#{dir_name}/*")
  
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
  files = Dir.glob('6.823/lab1/data/original/*')  
  
  names = files.map { |file| File.basename(file) }.
                map { |file| file[0...file.index('_base')] }
  Hash[*names.zip(files).flatten]
end

def bench_values(cases, base_dir = 'original')  
  {}.tap do |values|
    cases.each do |name, file|
      numbers = File.read(file.gsub('/original/', "/#{base_dir}/")).split(',').
                     select { |token| !token.empty? }.map { |token| token.to_i }
      sum = numbers.inject(0) { |acc, n| acc + n }.to_f
      percentages = numbers.map { |n| n / sum }    
      values[name] = percentages
    end
  end
end

def bench_detailed_values(cases, base_dir = 'detailed')
  {}.tap do |values|
    cases.each do |name, file|
      reg_stats, numbers = nil, nil
      File.open(file.gsub('/original/', "/#{base_dir}/"), 'r') do |f|
        nregs = f.gets.to_i
        reg_stats = (0...nregs).map do
          f.gets.strip.split(',').select { |token| !token.empty? }.
                 map { |token| token.to_i }          
        end
        numbers = f.gets.split(',').select { |token| !token.empty? }.
                         map { |token| token.to_i }
      end
      reg_stats.each do |stat|
        stat.each_index { |i| stat[i] /= numbers[i].to_f }
      end
    
      values[name] = {:numbers => numbers, :reg_stats => reg_stats}
    end
  end
end
