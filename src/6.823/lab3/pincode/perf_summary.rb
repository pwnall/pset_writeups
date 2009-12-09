#!/usr/bin/env ruby
#
# Reports cache performance statistics.
#
# Author:: Victor Costan
# Copyright:: none
# License:: Public Domain

if ARGV[0]
  dirname = ARGV[0]
else
  dirname = Dir.glob('results_*').sort.last
end
print "Stats from test run in #{dirname}\n"

tests = Hash[*Dir.glob("#{dirname}/*.out").map { |entry|
  name = File.basename(entry).split(/_|\./).first
  numbers = File.read(entry).split(' ').select { |t| t.to_i.to_s == t}.
                 map { |t| t.to_i} 
  stats = { :pt_good => numbers[0], :pt_total => numbers[0] + numbers[1],
            :pnt_good => numbers[2], :pnt_total => numbers[2] + numbers[3] }
  stats[:pt_prec] = (stats[:pt_total] == 0) ? 1.0 :
                    stats[:pt_good].to_f / stats[:pt_total]
  stats[:pnt_prec] = (stats[:pnt_total] == 0) ? 1.0 :
                     stats[:pnt_good].to_f / stats[:pnt_total]
  stats[:prec] = (stats[:pt_good] + stats[:pnt_good]).to_f /
                 (stats[:pt_total] + stats[:pnt_total])
  [name, stats]
}.flatten]

print("%-14s | %7s | %7s | %7s\n" % ['Test', 'Total', 'Taken', 'Not Taken'])
tests.keys.sort.each do |test|
  stats = tests[test]
  print("%-14s | %1.5f | %1.5f | %1.5f\n" %
        [test, stats[:prec], stats[:pt_prec], stats[:pnt_prec]])
end

averages = [:prec, :pt_prec, :pnt_prec].map do |key|
  tests.map { |name, stats| stats[key] }.
        inject(0) { |acc, n| acc + n } / tests.length
end
print("%-14s | %1.5f | %1.5f | %1.5f\n" % (['Average'] + averages))

totals = [:pt_good, :pt_total, :pnt_good, :pnt_total].map do |key|
  tests.map { |name, stats| stats[key] }.
        inject(0) { |acc, n| acc + n } / tests.length
end
totals = [(totals[0] + totals[2]).to_f / (totals[1] + totals[3]),
          totals[0] / totals[1].to_f, totals[2] / totals[3].to_f]
print("%-14s | %1.5f | %1.5f | %1.5f\n" % (['Total'] + totals))
