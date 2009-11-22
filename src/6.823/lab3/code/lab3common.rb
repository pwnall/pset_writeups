#!/usr/bin/env ruby
#
# Author:: Victor Costan
# Copyright:: none
# License:: Public Domain


def bench_cases_fix_names(dir_name = 'aligned')
  files = Dir.glob("6.823/lab3/data/#{dir_name}/*")
  
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
  files = Dir.glob('6.823/lab3/data/original/*.txt')  
  
  names = files.map { |file| File.basename(file) }.
                map { |file| file[0...file.index('_base')] }
  Hash[*names.zip(files).flatten]
end

def predictor_accuracy(cases, base_dir = 'original')  
  {}.tap do |values|
    cases.each do |name, file|
      numbers = File.read(file).split(' ').select { |t| t.to_i.to_s == t}.
                     map { |t| t.to_i} 
      stats = { :pt_good => numbers[0], :pt_total => numbers[0] + numbers[1],
                :pnt_good => numbers[2], :pnt_total => numbers[2] + numbers[3] }
      stats[:pt_prec] = (stats[:pt_total] == 0) ? 1.0 :
                        stats[:pt_good].to_f / stats[:pt_total]
      stats[:pnt_prec] = (stats[:pnt_total] == 0) ? 1.0 :
                         stats[:pnt_good].to_f / stats[:pnt_total]
      stats[:prec] = (stats[:pt_good] + stats[:pnt_good]).to_f /
                     (stats[:pt_total] + stats[:pnt_total])
      values[name] = stats
    end
  end
end
