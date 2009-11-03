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
data_sets = {'r8b2a1' => '1k' , 'r9b2a1' => '2k', 'r10b2a1' => '4k',
             'r11b2a1' => '8k', 'r12b2a1' => '16k', 'r13b2a1' => '32k',
             'r14b2a1' => '64k', 'r15b2a1' => '128k', 'r16b2a1' => '256k'}
stats = data_sets.keys.map do |data_set|
  values = cache_perf_values(cases, data_set)
  [data_set, values]
end

Gnuplot.open do |gp|
  maxpoints = 4
  Gnuplot::Plot.new gp do |plot|
    plot.terminal 'png small size 1024,768'
    plot.output '6.823/lab2/figs/working_set.png'
    plot.ylabel '% Misses'
    plot.xlabel 'Benchmark'
    
    xtics = []
    stats.first.last.keys.sort.each_with_index { |name, i| xtics << [name, i] }
    plot.xtics '(' + xtics.map { |name, i| %Q|"#{name}" #{i}| }.join(', ') + ')'

    stats.each do |data_set|
      name, data = *data_set
      bench_names = data.keys.sort
      bench_values = bench_names.map do |bench_name|
        data[bench_name][:pp].first * 100
      end
      plot.data << Gnuplot::DataSet.new([(0...bench_names.length).to_a,
                                        bench_values]) do |ds|
        ds.title = data_sets[name]
        ds.with = 'lines'
        ds.linewidth = 1
      end
    end
  end
end
