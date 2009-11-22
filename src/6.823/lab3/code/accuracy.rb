#!/usr/bin/env ruby
#
# Author:: Victor Costan
# Copyright:: none
# License:: Public Domain

require 'rubygems'
require 'gnuplot'
require '6.823/lab3/code/lab3common.rb'

bench_cases_fix_names 'original'
cases = bench_cases
stats = predictor_accuracy cases
averages = {}
[:prec, :pt_prec, :pnt_prec].each do |key|
  averages[key] = stats.map { |name, stat| stat[key] }.
      inject(0) { |acc, n| acc + n } / stats.length
end
totals = [:pt_good, :pt_total, :pnt_good, :pnt_total].map do |key|
  stats.map { |name, stat| stat[key] }.inject(0) { |acc, n| acc + n }
end
stats['{}Average'] = averages
stats['{}Total'] = {
  :prec => (totals[0] + totals[2]).to_f / (totals[1] + totals[3]),
  :pt_prec => totals[0] / totals[1].to_f,
  :pnt_prec => totals[2] / totals[3].to_f
}

File.open('6.823/lab3/figs/accuracy.tex', 'w') do |f|
  f.write "\\begin{tabular}{lrrr}\n\\hline\n"
  f.write "Test & Total Accuracy & Taken Accuracy & Not Taken Accuracy"
  f.write " \\\\\n\\hline\n"
  stats.keys.sort.each do |name|
    f.write "#{name} "
    [:prec, :pt_prec, :pnt_prec].each do |s|
      f.write "& #{"%.2f" % (stats[name][s] * 100)}\\% "
    end
    f.write " \\\\\n\\hline\n"
  end
  f.write "\\end{tabular}\n"
end
