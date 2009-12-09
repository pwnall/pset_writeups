#!/usr/bin/env ruby
#
# Author:: Victor Costan
# Copyright:: none
# License:: Public Domain

require 'rubygems'
require 'gnuplot'
require '6.823/lab1/code/lab1common.rb'

bench_cases_fix_names 'original'
bench_cases_fix_names 'accurate'
cases = bench_cases
originals = bench_values(bench_cases)
accurates = bench_values(bench_cases, 'accurate')

def mse(v1, v2)
  raise "The vectors don't have the same length" unless v1.length == v2.length
  Math.sqrt((0...v1.length).map { |i| (v1[i] - v2[i]) ** 2 }.
                            inject(0) { |acc, n| acc + n } / v1.length)
end

max_distance = 3
File.open('6.823/lab1/figs/accurate_delta.tex', 'w') do |f|
  f.write "\\begin{tabular}{lrrrr}\n\\hline\n"
  f.write "Test & MSE"
  1.upto(max_distance) { |d| f.write " & Distance #{d}" }
  f.write " \\\\\n\\hline\n"
  originals.keys.sort.each do |name|
    v1, v2 = originals[name], accurates[name]
    f.write "#{name} & #{'%.3f' % mse(v1, v2)}\\%"
    0.upto(max_distance - 1) do |d|
      f.write ' & '
      f.write('%+.3f' % (v1[d - 1] - v2[d - 1]))
      f.write "\\%"
    end
    f.write " \\\\\n\\hline\n"
  end
  f.write "\\end{tabular}\n"
end
