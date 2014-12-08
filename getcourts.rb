#!/usr/local/bin/ruby

require_relative 'smtp_google_mailer'
require_relative 'player_pool'
require_relative 'meetup_updater'
require_relative 'daily_reservation'
require_relative 'log'

require 'optparse'
require 'watir-webdriver'
require 'set'
require 'time'
require 'yaml'
require 'net/smtp'
require 'tlsmail'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: getcourts.rb [options]"
  opts.on('-u', '--conf configuration', 'configuration file') { |v| options[:conf] = v }
  opts.on('-l', '--logfile logfile', 'log file') { |v| options[:logfile] = v }
end.parse!

cnf = YAML::load_file(options[:conf])
Log.initialize(options[:logfile])

date = Date::today + 3
mailer = SMTPGoogleMailer.new(cnf[:smtp], date)
DailyReservation.initialize(cnf[:daily_reservations], date)
Log.info DailyReservation.to_s

player_pool = PlayerPool.new(cnf[:users], date)
mailer.send_mail('Reserving Courts')
player_pool.fill_reservations
mailer.send_mail('Done Reserving Courts -> Updating Meetup')

begin
  meetup_updater = MeetupUpdater.new(cnf[:meetup])
  meetup_updater.update_meetup(date, DailyReservation.get_existing_reservations)

  mailer.send_mail('Done Updating Meetup -> Logging out')
rescue Exception => exception
  Log.warn exception.message
  Log.warn exception.backtrace.inspect
end
mailer.send_mail('Done')
