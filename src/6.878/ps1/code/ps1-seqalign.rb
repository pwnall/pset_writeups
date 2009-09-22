#!/usr/bin/env ruby19
#
# Needleman-Wunsch sequence alignment. 
#
# Author:: Victor Costan
# Copyright:: none
# License:: Public Domain

# This program needs the bio gem to run. Install with the following command:
# gem install bio
require 'bio'
require 'pp'

# Aligns two sequences accoding to the Needleman-Wunsch algorithm.
def align_sequences_nm(sequence1, sequence2, scores)
  # Dynamic programming.
  dp = Array.new(sequence1.length + 1) { Array.new(sequence2.length + 1) }
  gap_score = scores['-']['-']
  dp[0][0] = [0, 0, 0, '|', '|']
  sequence1.chars.each_with_index do |c, i|
    dp[i + 1][0] = [(i + 1) * gap_score, 1, 0, c, '-']
  end
  sequence2.chars.each_with_index do |c, j|
    dp[0][j + 1] = [(j + 1) * gap_score, 0, 1, '-', c]
  end
  sequence1.chars.each_with_index do |base1, i|
    sequence2.chars.each_with_index do |base2, j|
      dp[i + 1][j + 1] = [[0, 1, '-', base2], [1, 0, '-', base1],
                          [1, 1, base1, base2]].map { |i1, j1, match1, match2|
        [dp[i - i1 + 1][j - j1 + 1].first + scores[match1][match2],
         i1, j1, match1, match2]
      }.max
    end
  end
  
  # Solution reconstruction.
  i, j = *[sequence1, sequence2].map(&:length)
  match_score = dp[i][j].first
  align1, align2 = '', ''
  until i == 0 && j == 0
    score, i1, j1, base1, base2 = *dp[i][j]
    align1 << base1; i -= i1 
    align2 << base2; j -= j1
  end
  
  # Return values
  scores = dp.map { |line| line.map(&:first) }
  words = { [1, 0] => '$\\uparrow$', [0, 1] => '$\\leftarrow$',
            [1, 1] => '$\\nwarrow$', [0, 0] => '$\\cdot$'}
  parents = dp.map { |line| line.map { |item| words[item[1, 2]] } }
  { :scores => scores, :parents => parents, :match_score => match_score,
    :aligns => [align1, align2].map(&:reverse) }
end

# Monkey-patch Bio::Sequence to read sequence data directly from files.
class Bio::Sequence
  def self.from_file(file_name)
    Bio::Sequence.input File.read(file_name)
  end
end

# Reads the scoring matrix from a file.
def scores_from_file(file_name)
  lines = File.read(file_name).split("\n").map { |line| line.split }
  gap_score = lines[0][0].to_f
  Hash[*lines[1..-1].map { |line|
    [line.first, Hash[*lines[0][1..-1].zip(line[1..-1].map { |token|
      token.to_i
    }).flatten].merge('-' => gap_score)]
  }.flatten].merge('-' => Hash.new { |key| gap_score })
end

# Produces a latex rendering of a matrix.
def latex_matrix(matrix)
  output = "\\begin{tabular}{|#{'r|' * matrix.first.length}}\n"
  output << "\\hline\n"
  output << matrix.map { |line| line.join(' & ') }.join("\\\\\n\\hline\n")
  output << "\\\\\n"
  output << "\\hline\n"
  output << "\\end{tabular}\n"
  output
end

# Produces a latex rendering of a table of data.
def latex_table(data, top_headings, left_headings)
  matrix = [[''] + top_headings] +
      left_headings.zip(data).map { |heading, line| [heading] + line }
  latex_matrix matrix
end

# main
if $0 == __FILE__
  unless ARGV.length == 3
    puts "Usage: #{$0} score_file sequence_1 sequence_2"
    exit
  end  
  sequences = ARGV[1..-1].map { |file_name| Bio::Sequence.from_file file_name }
  scores = scores_from_file ARGV[0]
  dp_result = align_sequences_nm(*(sequences + [scores]))
  
  puts "Alignment:"
  puts "\\begin{verbatim}\n#{dp_result[:aligns].join("\n")}\n\\end{verbatim}"
  puts "Score: #{dp_result[:match_score]}"
  
  # Only print detailed stats for small matrices.
  if sequences.map(&:length).max <= 10
    puts "Score matrix: "
    puts latex_table(dp_result[:scores], ['|'] + sequences[1].chars.to_a,
                     ['|'] + sequences[0].chars.to_a)
    
    puts "Parents matrix: "
    puts latex_table(dp_result[:parents], ['|'] + sequences[1].chars.to_a,
                     ['|'] + sequences[0].chars.to_a)
  end
end
