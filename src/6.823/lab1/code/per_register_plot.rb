#!/usr/bin/env ruby
#
# Author:: Victor Costan
# Copyright:: none
# License:: Public Domain

# This program needs the gnuplot gem to run. Install with the following command:
# gem install gnuplot

require 'rubygems'
require 'gnuplot'
require '6.823/lab1/code/lab1common.rb'

bench_cases_fix_names 'detailed'
cases = bench_cases
details = bench_detailed_values bench_cases, 'detailed'

reg_count = details.values.first[:reg_stats].length
stat_count = details.values.first[:numbers].length
register_stats = (0...reg_count).map do |reg|
  (0...stat_count).map do |i|    
    details.map { |name, detail| detail[:reg_stats][reg][i] }.
            inject(0) { |acc, n| acc + n} / details.length
  end
end

Gnuplot.open do |gp|
  Gnuplot::Plot.new gp do |plot|
    plot.terminal 'png small size 1024,768'
    plot.output '6.823/lab1/figs/reg_frequencies.png'
    plot.ylabel '% Instructions'
    plot.xlabel 'Distance'

    register_stats.each_with_index do |stats, i|
      next if stats.max < 0.005
      plot.data << Gnuplot::DataSet.new([(1..stat_count).to_a, stats]) do |ds|
        ds.title = "Reg #{i}"
        ds.with = 'lines'
        ds.linewidth = 1
      end
    end
  end
end
