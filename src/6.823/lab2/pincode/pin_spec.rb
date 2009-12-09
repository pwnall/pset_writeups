#!/usr/bin/env ruby
#
# Runs the SPEC benchmarks using a PIN tool.
#
# Author:: Victor Costan
# Copyright:: none
# License:: Public Domain

require 'English'
require 'fileutils'
require 'socket'
require 'yaml'

# Configuration pointing to the SPEC tests and PIN tool to be used.
def load_configuration
  # Default configuration.
  config = File.open('pin_spec.yml', 'r') { |f| YAML.load f }
  
  if ARGV[0]
    # If the first argument is a Yaml configuration file, use that to override
    # the default configuration.
    if ARGV[0][-4, 4] == '.yml'
      config.merge! File.open(ARGV[0], 'r') { |f| YAML.load f }
    else
      # Argument 1: the output directory.
      config[:output_dir] = ARGV[0]
    end
  end
  
  # Supply a default output directory if no directory is given.
  config[:output_dir] ||= 'results_' + Time.now.strftime("%Y%m%d%H%M%S")
  config[:output_dir] = File.expand_path config[:output_dir],
                                         File.dirname(__FILE__)

  # Argument 2: pintool binary
  config[:tool_binary] = ARGV[1] if ARGV[1]
  config[:tool_binary] = File.expand_path ARGV[1] || config[:tool_binary],
                                          File.dirname(__FILE__)

  # Arguments 3..n: pintool arguments
  if ARGV[2]
    config[:tool_args] = ARGV[2..-1]
  end
  if config[:tool_args].respond_to? :to_str
    config[:tool_args] = config[:tool_args].split
  end

  # Suite location.
  suite_file = config[:suite_path] || './spec_suite.yml'
  config[:suite] = File.open(suite_file, 'r') { |f| YAML.load f }

  # Filter out tests in the suite.
  config[:suite].delete_if do |test_name, test_config|
    config[:skip_tests].include? test_name
  end  

  config
end

# Runs the SPEC test suite.
#
# Args::
#   config:: the configuration read by load_configuration
def run_suite(config)
  # Build the sandbox.
  FileUtils.rm_rf config[:output_dir] if File.exist? config[:output_dir]
  FileUtils.mkdir_p config[:output_dir]
  File.chmod 0777, config[:output_dir]
  temp_dir = File.join config[:output_dir], '__temp_' +
      "#{Time.now.strftime("%Y%m%d%H%M%S")}_#{$PID}_#{rand(1 << 20)}"
  FileUtils.mkdir_p temp_dir
  File.chmod 0777, config[:output_dir]
  
  # Figure out PIN's configuration.
  pin_config = { :temp_dir => temp_dir, :tool_binary => config[:tool_binary],
                 :tool_args => config[:tool_args] || [] }
  if /^vlsifarm/ =~ Socket.gethostname  # On vlsifarm.
    pin_config[:binary] = '/mit/6.823/Fall09/bin/pin'
  else  # On linerva.
    pin_config[:tool_binary] += '.so'
    pin_config[:binary] = '/mit/6.823/Fall09/Pin2009/pin'
  end
  
  
  # Run the tests.
  test_number = 0
  config[:suite].keys.sort.each do |test_name|
    test_data = config[:suite][test_name]
    
    next if config[:skip_tests].include? test_name
    test_number += 1
    puts "Test #{test_name} -- #{test_number} of #{config[:suite].length}"
    
    out_file = File.basename(test_data['binary']) + '.out'
    pin_output = File.join config[:output_dir], out_file
    run_test test_data, pin_config, pin_output
  end
    
  # Tear down the sandbox.
  #FileUtils.rm_rf temp_dir  
end

# Runs a test in the SPEC suite.
def run_test(test_data, pin_config, pin_output)
  command = %Q|"#{pin_config[:binary]}" -t "#{pin_config[:tool_binary]}"| +
      %Q| -o "#{pin_output}" | +
      pin_config[:tool_args].map { |arg| %Q|"#{arg}"| }.join(' ') + ' -- ' +
      %Q|"#{test_data['binary']}" | +
      test_data['args'].map { |arg| %Q|"#{arg}"| }.join(' ')
  command += %Q| < "#{test_data['stdin']}"| if test_data['stdin']
  
  Dir.chdir(test_data['directory'] || pin_config[:temp_dir]) do
    puts command + "\n"
    Kernel.system command
  end
end

# Writes a marker file indicating the tests have completed running.
def write_success_marker(config)
  success_file = File.join config[:output_dir], 'success.yml'
  File.open(success_file, 'w') { |f| YAML.dump config, f }  
end

if __FILE__ == $0
  config = load_configuration
  run_suite config
  write_success_marker config
end
