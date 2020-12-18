#! /usr/bin/env ruby
#
# metrics-ses-usage
#
# DESCRIPTION:
#   Gets your SES sending usage and limit and store them into Graphite.
#
# OUTPUT:
#   plain-text
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
#   ./metrics-cloudwatch-ses -r eu-west-1
#
# NOTES:
#
# LICENSE:
#   Copyright 2018 Nicolas Boutet
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/metric/cli'
require 'sensu-plugins-aws'
require 'aws-sdk'

class MetricsSESUsage < Sensu::Plugin::Metric::CLI::Graphite
  include Common
  option :aws_region,
         short:       '-r AWS_REGION',
         long:        '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default:     'us-east-1'

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short:       '-s SCHEME',
         long:        '--scheme SCHEME',
         required:    true,
         default:     'aws.ses.usage'

  def run
    begin
      ses = Aws::SES::Client.new
      response = ses.get_send_quota
    rescue StandardError => e
      unknown "An issue occured while communicating with the AWS SES API: #{e.message}"
    end

    unknown 'Empty response from AWS SES API' if response.empty? # Can this happen?

    percent = ((response.sent_last_24_hours.to_f / response.max_24_hour_send.to_f) * 100).to_f.round(2)

    output "#{config[:scheme]}.max_24_hour_send", response.max_24_hour_send.to_f
    output "#{config[:scheme]}.max_send_rate", response.max_send_rate.to_f
    output "#{config[:scheme]}.sent_last_24_hours", response.sent_last_24_hours.to_f
    output "#{config[:scheme]}.quota_used", percent

    ok
  end
end
