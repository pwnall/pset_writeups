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
cache_sets = {
  'ccc_4k' => { 'r9b2a1 pp' => 'baseline', 'r10b2a1 pp' => 'rows',
                'r9b3a1 pp' => 'block size', 'r9b2a2 pp' => 'associativity' },
  'ccc_8k' => { 'r9b2a1 pp' => 'baseline', 'r11b2a1 pp' => 'rows',
                'r9b4a1 pp' => 'block size', 'r9b2a4 pp' => 'associativity' },
  'ccc_16k' => { 'r9b2a1 pp' => 'baseline',
                 'r12b2a1 vp' => 'rows physical/physical',
                 'r12b2a1 vv' => 'rows virtual/physical',
                 'r12b2a1 pp' => 'rows virtual/virtual',
                 'r9b5a1 pp' => 'block size physical/physical',
                 'r9b5a1 vp' => 'block size virtual/physical',
                 'r9b5a1 vv' => 'block size virtual/virtual',
                 'r9b2a8 pp' => 'associativity physical/physical',
                 'r9b2a8 vp' => 'associativity virtual/physical',
                 'r9b2a8 vv' => 'associativity virtual/virtual',
                 },
  'ccc_32k' => { 'r9b2a1 pp' => 'baseline',
                 'r13b2a1 vp' => 'rows physical/physical',
                 'r13b2a1 vv' => 'rows virtual/physical',
                 'r13b2a1 pp' => 'rows virtual/virtual',
                 'r9b6a1 pp' => 'block size physical/physical',
                 'r9b6a1 vp' => 'block size virtual/physical',
                 'r9b6a1 vv' => 'block size virtual/virtual',
                 'r9b2a16 pp' => 'associativity physical/physical',
                 'r9b2a16 vp' => 'associativity virtual/physical',
                 'r9b2a16 vv' => 'associativity virtual/virtual',
                 },
}

stats = cache_sets.keys.map do |cache_set|
  cache_stats = cache_sets[cache_set].keys.map do |data_set|
    values = cache_perf_values(cases, data_set.split.first)
    [data_set, values]    
  end
  [cache_set, cache_stats]
end

Gnuplot.open do |gp|
  maxpoints = 4
  stats.each do |cache_set, cache_stats|
    Gnuplot::Plot.new gp do |plot|
      plot.terminal 'png small size 1024,768'
      plot.output "6.823/lab2/figs/#{cache_set}.png"
      plot.ylabel '% Misses'
      plot.xlabel 'Benchmark'
      
      xtics = []
      cache_stats.first.last.keys.sort.each_with_index do |name, i|
        xtics << [name, i]
      end
      plot.xtics '(' + xtics.map { |name, i| %Q|"#{name}" #{i}| }.join(', ') +
                 ')'
  
      cache_stats.each do |data_set|
        name, data = *data_set
        bench_names = data.keys.sort
        bench_values = bench_names.map do |bench_name|
          data[bench_name][name.split.last.to_sym].first * 100
        end
        plot.data << Gnuplot::DataSet.new([(0...bench_names.length).to_a,
                                          bench_values]) do |ds|
          ds.title = cache_sets[cache_set][name]
          ds.with = 'lines'
          ds.linewidth = 1
        end
      end
    end
  end
end
