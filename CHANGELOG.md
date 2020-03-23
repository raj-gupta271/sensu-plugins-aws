# Change Log
This project adheres to [Semantic Versioning](http://semver.org/).

This CHANGELOG follows the format listed [here](https://github.com/sensu-plugins/community/blob/master/HOW_WE_CHANGELOG.md)

## [Unreleased]

## [1.0.0] - 2020-03-23
### Added
- `check-ebs-burst-limit.rb`: add `--tag`/`-t` option to specify a volume tag to output in status message. (@boutetnico)
- `check-cloudwatch-alarms.rb`: `--name-prefix`/`-p` option added to filter alarm names by a prefix. (@boutetnico)
- new `metrics-reservation-utilization.rb`: retrieve metrics about reserved instances usage. (@boutetnico)
- new `check-expiring-reservations.rb`: check instance reservations and warn about upcoming expiration. (@boutetnico)

