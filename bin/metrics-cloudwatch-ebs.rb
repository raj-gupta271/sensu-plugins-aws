#! /usr/bin/env ruby
#
# metrics-cloudwatch-ebs
#
# DESCRIPTION:
#   Fetch EBS metrics from CloudWatch and store them into Graphite for longer term storage
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
#   ./metrics-cloudwatch-ebs -m BurstBalance
#   ./metrics-cloudwatch-ebs -m BurstBalance -t Name
#   ./metrics-cloudwatch-ebs -m BurstBalance -t Name -F "{name:tag-value,values:[staging]}"
#
# NOTES:
#
# LICENSE:
#   Copyright 2018 Nicolas Boutet
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/metric/cli'
require 'sensu-plugins-aws/filter'
require 'aws-sdk'
require 'sensu-plugins-aws'
require 'time'

class CloudWatchEc2Metrics < Sensu::Plugin::Metric::CLI::Graphite
  include Common
  include Filter

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short:       '-s SCHEME',
         long:        '--scheme SCHEME',
         default:     'aws.cloudwatch.ebs'

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

  option :tag,
         description: 'Add instance TAG value to metrics instead of instance id.',
         short:       '-t TAG',
         long:        '--tag TAG'

  option :filter,
         short:       '-F FILTER',
         long:        '--filter FILTER',
         description: 'String representation of the filter to apply',
         default:     '{}'

  def cloud_watch
    @cloud_watch ||= Aws::CloudWatch::Client.new
  end

  def cloud_watch_metric(metric_name, value, volume)
    cloud_watch.get_metric_statistics(
      namespace: 'AWS/EBS',
      metric_name: metric_name,
      dimensions: [
        {
          name: 'VolumeId',
          value: volume.ebs.volume_id
        }
      ],
      statistics: [value],
      start_time: config[:end_time] - config[:period],
      end_time: config[:end_time],
      period: config[:period]
    )
  end

  def print_statistics(statistics, instance)
    statistics.each do |key, static|
      instance.block_device_mappings.each do |volume|
        r = cloud_watch_metric(key, static, volume)
        keys = [config[:scheme]]
        instance_name = config[:tag] ? instance_tag(instance, config[:tag]).to_s : instance.instance_id
        keys.concat [instance_name, volume.device_name, key, static]
        output(keys.join('.'), r[:datapoints].first[static.downcase]) unless r[:datapoints].first.nil?
      end
    end
  end

  def print_metrics(metrics, instance)
    metrics_statistic = {
      'BurstBalance' => 'Average'
    }

    metrics.each do |metric|
      statistic = metrics_statistic.select { |key, _| key == metric }
      if statistic.empty?
        unknown "Invalid metric #{metric}. Possible values: #{metrics_statistic.keys.join(',')}"
      end
      print_statistics(statistic, instance)
    end
  end

  def parse_metrics(metrics)
    if metrics.nil?
      unknown 'No metrics provided. See usage for details'
    end
    metrics.split(',')
  end

  def instance_tag(instance, tag_name)
    tag = instance.tags.select { |t| t.key == tag_name }.first
    tag.nil? ? '' : tag.value
  end

  def run
    filters = Filter.parse(config[:filter])
    filters.push(
      name: 'instance-state-name',
      values: ['running']
    )
    ec2 = Aws::EC2::Client.new
    instances = ec2.describe_instances(
      filters: filters
    )

    metrics = parse_metrics(config[:metrics])

    instances.reservations.each do |reservation|
      reservation.instances.each do |instance|
        print_metrics(metrics, instance)
      end
    end

    ok
  end
end
