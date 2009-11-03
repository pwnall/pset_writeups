#!/usr/bin/env ruby
#
# Author:: Victor Costan
# Copyright:: none
# License:: Public Domain

require 'rubygems'
require 'gnuplot'
require '6.823/lab2/code/lab2common.rb'

bench_cases_fix_names 'aligned'
cases = bench_cases
stats = aligned_access_values(cases)
stats.keys.each do |name|
  total_r, total_w, aligned_r, aligned_w = *stats[name]
  stats[name] =  [(total_r - aligned_r) / total_r.to_f,
                  (total_w - aligned_w) / total_w.to_f,
                  (total_r + total_w - aligned_r - aligned_w) /
                  (total_r + total_w).to_f]
end
sums = stats.values.inject([0, 0, 0]) do |acc, stat|
  acc.zip(stat).map { |a, b| a + b }
end
avgs = sums.map { |s| s / stats.length.to_f }
stats['{}Averages'] = avgs

File.open('6.823/lab2/figs/unaligned_accesses.tex', 'w') do |f|
  f.write "\\begin{tabular}{lrrr}\n\\hline\n"
  f.write "Test & \\% unaligned reads & \\% unaligned writes & "
  f.write "\\% unaligned accesses"
  f.write " \\\\\n\\hline\n"
  stats.keys.sort.each do |name|
    f.write "#{name} "
    f.write stats[name].map { |number| "& #{'%.5f' % (number * 100)}\\% " }.join
    f.write " \\\\\n\\hline\n"
  end
  f.write "\\end{tabular}\n"
end
