#!/usr/local/bin/ruby

require_relative 'smtp_google_mailer'
require_relative 'player'
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

Player.initialize(cnf[:users], log)

begin
  while DailyReservation.not_done? and Player.have_players?
    reservation = DailyReservation.next_reservation
    log.info("Finding " + reservation.to_s)
    player = Player.find_available_player(reservation.start_time)
    if player.nil?
      log.warn "No one available to reserve a court @ " + reservation.start_time
    else
      player.reserve(reservation)
    end
    reservation.make_reservation
  end

  me = Player.admin
  smtp_info = begin
    date_str = "%d/%d/%d" % [me.date.month, me.date.day, me.date.year]
    subject = 'Court reservations for ' + date_str
    body = "\n-------- DEBUG LOG ---------\n" +
        File.read(options[:logfile])
    mailer = SMTPGoogleMailer.new(cnf[:smtp])
    mailer.send_plain_email('oskarmellow@gmail.com',
                            'jeffnamkung@gmail.com',
                            subject, body)
  rescue Exception => exception
    log.warn exception.message
    log.warn exception.backtrace.inspect
    $stderr.puts "Could not find SMTP info"
  end

  meetup_updater = MeetupUpdater.new(cnf[:meetup])
  meetup_updater.update_meetup(Player.admin.date,
                               Player.get_existing_reservations)
rescue Exception => exception
  log.warn exception.message
  log.warn exception.backtrace.inspect
end
Player.logout
