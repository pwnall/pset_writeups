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

bench_cases_fix_names 'original'
bench_cases_fix_names 'accurate'
cases = bench_cases
originals = bench_values(bench_cases)


Gnuplot.open do |gp|
  Gnuplot::Plot.new gp do |plot|
    plot.terminal 'png small size 1024,768'
    plot.output '6.823/lab1/figs/frequencies.png'
    plot.ylabel '% Instructions'
    plot.xlabel 'Distance'

    originals.keys.sort.each do |name|
      data = originals[name]
      plot.data << Gnuplot::DataSet.new([(1..data.length).to_a, data]) do |ds|
        ds.title = name
        ds.with = 'lines'
        ds.linewidth = 1
      end
    end
  end

  maxpoints = 4
  Gnuplot::Plot.new gp do |plot|
    plot.terminal 'png small size 1024,768'
    plot.output '6.823/lab1/figs/frequencies_zoom.png'
    plot.ylabel '% Instructions'
    plot.xlabel 'Distance'

    originals.keys.sort.each do |name|
      data = originals[name]
      plot.data << Gnuplot::DataSet.new([(1..maxpoints).to_a,
                                        data[0, maxpoints]]) do |ds|
        ds.title = name
        ds.with = 'lines'
        ds.linewidth = 1
      end
    end
  end
end
