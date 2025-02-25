#! /usr/bin/env ruby
#
# check-emr-cluster
#
# DESCRIPTION:
#   This plugin checks if a cluster exists.
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
#
# USAGE:
#   ./check-emr-cluster.rb --aws-region eu-west-1 --use-iam --warning-over 14400 --critical-over 21600
#
# NOTES:
#
# LICENSE:
#   Copyright (c) 2015, Olivier Bazoud, olivier.bazoud@gmail.com
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'aws-sdk'

class CheckEMRCluster < Sensu::Plugin::Check::CLI
  option :aws_access_key,
         short: '-a AWS_ACCESS_KEY',
         long: '--aws-access-key AWS_ACCESS_KEY',
         description: "AWS Access Key. Either set ENV['AWS_ACCESS_KEY'] or provide it as an option",
         default: ENV['AWS_ACCESS_KEY']

  option :aws_secret_access_key,
         short: '-k AWS_SECRET_KEY',
         long: '--aws-secret-access-key AWS_SECRET_KEY',
         description: "AWS Secret Access Key. Either set ENV['AWS_SECRET_KEY'] or provide it as an option",
         default: ENV['AWS_SECRET_KEY']

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default: 'us-east-1'

  option :use_iam_role,
         short: '-u',
         long: '--use-iam',
         description: 'Use IAM role authenticiation. Instance must have IAM role assigned for this to work'

  option :warning_over,
         description: 'Warn if cluster\'s age is greater than provided age in seconds',
         short: '-w SECONDS',
         long: '--warning-over SECONDS',
         default: -1,
         proc: proc(&:to_i)

  option :critical_over,
         description: 'Critical if cluster\'s age is greater than provided age in seconds',
         short: '-c SECONDS',
         long: '--critical-over SECONDS',
         default: -1,
         proc: proc(&:to_i)

  option :warning_under,
         description: 'Warn if cluster\'s age is lower than provided age in seconds',
         short: '-w SECONDS',
         long: '--warning-under SECONDS',
         default: -1,
         proc: proc(&:to_i)

  option :critical_under,
         description: 'Critical if cluster\'s age is lower than provided age in seconds',
         short: '-C SECONDS',
         long: '--critical-under SECONDS',
         default: -1,
         proc: proc(&:to_i)

  def aws_config
    { access_key_id: config[:aws_access_key],
      secret_access_key: config[:aws_secret_access_key],
      region: config[:aws_region] }
  end

  def humanize(secs)
    [[60, :seconds], [60, :minutes], [24, :hours], [1000, :days]].map do |count, name|
      if secs > 0
        secs, n = secs.divmod(count)
        "#{n.to_i} #{name}"
      end
    end.compact.reverse.join(' ')
  end

  def run
    aws_config = {}
    if config[:use_iam_role].nil?
      aws_config[:access_key_id] = config[:aws_access_key]
      aws_config[:secret_access_key] = config[:aws_secret_access_key]
    end

    emr = Aws::EMR::Client.new(aws_config.merge!(region: config[:aws_region]))
    
    emr_clusters = emr.list_clusters(created_after: Time.now - 24 * 60 * 60 * 30, created_before: Time.now).clusters
    running_clusters = emr_clusters.select { |c| c.status.state == "RUNNING" }
    waiting_clusters = emr_clusters.select { |c| c.status.state == "WAITING" }
    
    #puts "#### ALl Clusters ####"
    #puts emr_clusters
    
    #puts "#### Running Clusters ####"
    #puts running_clusters
    
    #puts "#### Waiting Clusters ####"
    #puts waiting_clusters
      
    for cluster in running_clusters
      state = cluster.status.state
      #puts "Cluster = #{cluster.name}, state = #{state}"
      if state == 'TERMINATED_WITH_ERRORS'
        warning "EMR cluster #{cluster.name} state is '#{state}'"
      else
        creation_date_time = cluster.status.timeline.creation_date_time
        end_date_time = cluster.status.timeline.end_date_time || Time.now
        age = end_date_time.to_i - creation_date_time.to_i
        if age >= config[:critical_over]
          critical "Critical EMR cluster #{cluster.name} running for #{humanize(age)} which is more than #{humanize(config[:critical_over])}"
        elsif age >= config[:warning_over]
          warning "Warning EMR cluster #{cluster.name} running for #{humanize(age)} which is more than #{humanize(config[:warning_over])}"
        elsif age <= config[:critical_under] && state == 'TERMINATED'
          critical "CriticalEMR cluster #{cluster.name} - #{humanize(age)} vs. #{humanize(config[:critical_under])}"
        elsif age <= config[:warning_under] && state == 'TERMINATED'
          warning "Warning EMR cluster #{cluster.name} - #{humanize(age)} vs. #{humanize(config[:warning_under])}"
        else
          puts("Ok EMR cluster #{cluster.name} running for - #{humanize(age)}")
        end
      end
    end
    ok "Status OK, No long running cluster"
  end
end
