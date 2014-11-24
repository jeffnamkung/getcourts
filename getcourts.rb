#!/usr/local/bin/ruby

require_relative 'smtp_google_mailer'
require_relative 'player_pool'
require_relative 'court_reservation'
require_relative 'meetup_updater'
require_relative 'daily_reservation'

require 'logger'
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
log = Logger.new(options[:logfile], 'daily')

DailyReservation.initialize(cnf[:daily_reservations])
puts DailyReservation.to_s

player_pool = PlayerPool.new(cnf[:users], log)
me = player_pool.admin
me.setup_mail(cnf[:smtp], options[:logfile])
me.send_mail('Logging In')
player_pool.login
me.send_mail('Done Logging -> Getting Existing Reservations')
player_pool.get_existing_reservations
me.send_mail('Done Getting Existing Reservations -> Reserving Courts')

begin
  while DailyReservation.not_done? and player_pool.have_players?
    reservation = DailyReservation.next_reservation
    log.info("Finding " + reservation.to_s)
    player = player_pool.find_available_player(reservation.start_time)
    if player.nil?
      log.warn "No one available to reserve a court @ " + reservation.start_time
    else
      player.reserve(reservation)
    end
    reservation.make_reservation
  end
rescue Exception => exception
  log.warn exception.message
  log.warn exception.backtrace.inspect
end

me.send_mail('Done Reserving Courts -> Updating Meetup')

begin
  meetup_updater = MeetupUpdater.new(cnf[:meetup])
  meetup_updater.update_meetup(player_pool.admin.date,
                               player_pool.get_existing_reservations)

  me.send_mail('Done Updating Meetup -> Logging out')
rescue Exception => exception
  log.warn exception.message
  log.warn exception.backtrace.inspect
end
player_pool.logout
me.send_mail('Done')
