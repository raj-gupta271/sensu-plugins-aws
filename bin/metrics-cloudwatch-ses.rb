#! /usr/bin/env ruby
#
# metrics-cloudwatch-ses
#
# DESCRIPTION:
#   Fetch SES metrics from CloudWatch and store them into Graphite for longer term storage
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
#   gem: sensu-plugin-aws
#   gem: time
#
# USAGE:
#   ./metrics-cloudwatch-ses -m Send
#   ./metrics-cloudwatch-ses -m Send,Open -p 3600
#
# NOTES:
#
# LICENSE:
#   Copyright 2018 Nicolas Boutet
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/metric/cli'
require 'aws-sdk'
require 'sensu-plugins-aws'
require 'time'

class CloudWatchSesMetrics < Sensu::Plugin::Metric::CLI::Graphite
  include Common
  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short:       '-s SCHEME',
         long:        '--scheme SCHEME',
         default:     'aws.cloudwatch.ses'

  option :aws_region,
         short:       '-r AWS_REGION',
         long:        '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default:     'us-east-1'

  option :metrics,
         description: 'Commas separated list of metric(s) to fetch',
         short:       '-m METRIC1,METRIC2',
         long:        '--metrics METRIC1,METRIC2'

  option :end_time,
         short:       '-t T',
         long:        '--end-time TIME',
         default:     Time.now,
         proc:        proc { |a| Time.parse a },
         description: 'CloudWatch metric statistics end time'

  option :period,
         short:       '-p N',
         long:        '--period SECONDS',
         default:     60,
         proc:        proc(&:to_i),
         description: 'CloudWatch metric statistics period'

  def cloud_watch
    @cloud_watch ||= Aws::CloudWatch::Client.new
  end

  def cloud_watch_metric(metric_name, value)
    cloud_watch.get_metric_statistics(
      namespace: 'AWS/SES',
      metric_name: metric_name,
      dimensions: [],
      statistics: [value],
      start_time: config[:end_time] - config[:period],
      end_time: config[:end_time],
      period: config[:period]
    )
  end

  def print_statistics(statistics)
    statistics.each do |key, static|
      r = cloud_watch_metric(key, static)
      keys = [config[:scheme]]
      keys.concat [key, static]
      output(keys.join('.'), r[:datapoints].first[static.downcase]) unless r[:datapoints].first.nil?
    end
  end

  def print_metrics(metrics)
    metrics_statistic = {
      'Bounce' => 'Sum',
      'Click' => 'Sum',
      'Complaint' => 'Sum',
      'Delivery' => 'Average',
      'Open' => 'Sum',
      'Reputation.BounceRate' => 'Average',
      'Reputation.ComplaintRate' => 'Average',
      'Send' => 'Sum'
    }

    metrics.each do |metric|
      statistic = metrics_statistic.select { |key, _| key == metric }
      if statistic.empty?
        unknown "Invalid metric #{metric}. Possible values: #{metrics_statistic.keys.join(',')}"
      end
      print_statistics(statistic)
    end
  end

  def parse_metrics(metrics)
    if metrics.nil?
      unknown 'No metrics provided. See usage for details'
    end
    metrics.split(',')
  end

  def run
    metrics = parse_metrics(config[:metrics])
    print_metrics(metrics)
    ok
  end
end
