#!/usr/bin/env ruby
#
# Author:: Victor Costan
# Copyright:: none
# License:: Public Domain


def bench_cases_fix_names(dir_name = 'aligned')
  files = Dir.glob("6.823/lab2/data/#{dir_name}/*")
  
  files.each_with_index do |file, i|
    ['.out', '.o'].each do |suffix|
      len = suffix.length
      next unless file[-len, len] == suffix
      File.rename file, file[0...-len] + '.txt'
      files[i] = file[0...-len]
    end
  end  
end

def bench_cases
  files = Dir.glob('6.823/lab2/data/aligned/*')  
  
  names = files.map { |file| File.basename(file) }.
                map { |file| file[0...file.index('_base')] }
  Hash[*names.zip(files).flatten]
end

def aligned_access_values(cases, base_dir = 'aligned')  
  {}.tap do |values|
    cases.each do |name, file|
      # total_reads, total_writes, aligned_reads, aligned_writes
      numbers = File.read(file.gsub('/aligned/', "/#{base_dir}/")).split(',').
                     select { |token| !token.empty? }.map { |token| token.to_i }
      values[name] = numbers
    end
  end
end

def cache_perf_values(cases, base_dir = 'r9b2a1')
  bench_cases_fix_names "x3/#{base_dir}"
  
  {}.tap do |values|
    cases.each do |name, file|
      # total_reads, total_writes, aligned_reads, aligned_writes
      stats = {}
      File.read(file.gsub('/aligned/', "/x3/#{base_dir}/")).split("\n").
           each do |line|
        label, number_string = *line.split(':')
        label = label.split.map { |token| token[0, 1] }.
                      select { |ch| "vp".index ch }.join.to_sym
        total_reads, total_writes, hit_reads, hit_writes = *number_string.
            split(',').select { |token| !token.empty? }.
            map { |token| token.to_i }
        numbers = [(total_reads + total_writes - hit_reads - hit_writes) /
                   (total_reads + total_writes).to_f,
            (total_reads - hit_reads) / total_reads.to_f,
            (total_writes - hit_writes) / total_writes.to_f]
        stats[label] = numbers
      end
      values[name] = stats
    end
  end  
end