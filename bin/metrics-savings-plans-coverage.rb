#! /usr/bin/env ruby
#
# savings-plans-coverage
#
# DESCRIPTION:
#   Gets Savings Plans Coverage of an AWS account.
#
# OUTPUT:
#   metric-data
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: aws-sdk
#   gem: sensu-plugin
#   gem: sensu-plugins-aws
#
# USAGE:
#   metrics-savings-plans-coverage.rb
#
# NOTES:
#
# LICENSE:
#   Copyright (c) 2020, Nicolas Boutet amd3002@gmail.com
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/metric/cli'
require 'aws-sdk'
require 'sensu-plugins-aws'

class SavingsPlansUtilizationMetrics < Sensu::Plugin::Metric::CLI::Graphite
  include Common

  option :from,
         short:       '-f TIME',
         long:        '--from TIME',
         default:     Time.now - 2 * 86_400, # start date cannot be after 2 days ago
         proc:        proc { |a| Time.parse a },
         description: 'The beginning of the time period that you want the usage and costs for (inclusive).'

  option :to,
         short:       '-t TIME',
         long:        '--to TIME',
         default:     Time.now,
         proc:        proc { |a| Time.parse a },
         description: 'The end of the time period that you want the usage and costs for (exclusive).'

  option :granularity,
         short:       '-g GRANULARITY',
         long:        '--granularity GRANULARITY',
         required:    false,
         in:          %w[HOURLY DAILY MONTHLY],
         description: 'The granularity of the Amazon Web Services coverage data for your Savings Plans.',
         default:     'DAILY'

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric.',
         short:       '-s SCHEME',
         long:        '--scheme SCHEME',
         default:     'sensu.aws.savings_plans_coverage'

  option :aws_region,
         short:       '-r AWS_REGION',
         long:        '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default:     'us-east-1'

  def run
    begin
      client = Aws::CostExplorer::Client.new(aws_config)

      utilization = client.get_savings_plans_coverage(
        time_period: {
          start: config[:from].strftime('%Y-%m-%d'),
          end: config[:to].strftime('%Y-%m-%d')
        },
        granularity: config[:granularity]
      )

      utilization.savings_plans_coverages.each do |period|
        period.to_h.each do |category, values|
          next if category.to_s == 'time_period' || category.to_s == 'attributes'
          values.to_h.each do |key, value|
            output "#{config[:scheme]}.#{category}.#{key}", value, Time.parse(period.time_period.end).to_i
          end
        end
      end
    rescue StandardError => e
      critical "Error: exception: #{e}"
    end
    ok
  end
end
