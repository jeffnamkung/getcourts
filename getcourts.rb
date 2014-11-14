#!/usr/local/bin/ruby

require_relative 'smtp_google_mailer'
require_relative 'player'
require_relative 'court_reservation'
require_relative 'meetup_updater'

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

players = []
for user in cnf[:users]
  players << Player.new(user, log)
end

court_times_by_day = Hash.new
court_times_by_day[0] = Array["09:00AM", "10:30AM"]
court_times_by_day[1] = Array["05:30PM", "05:30PM", "05:30PM",
                              "07:00PM", "07:00PM", "07:00PM"]
court_times_by_day[2] = Array["05:30PM", "05:30PM", "05:30PM",
                              "07:00PM", "07:00PM", "07:00PM", "9:30"]
court_times_by_day[3] = Array["05:30PM", "05:30PM", "07:00PM", "07:00PM"]
court_times_by_day[4] = Array["05:30PM", "05:30PM", "07:00PM", "07:00PM"]
court_times_by_day[5] = Array[]
court_times_by_day[6] = Array["09:00AM", "09:00AM", "10:30AM", "10:30AM"]

def rank_courts(courts)
  rankings = Hash.new
  i = 0
  courts.each do |court|
    rankings[i] = court
    i += 1
  end
  rankings
end

court_tiers = Array.new
court_tiers[0] = Array["14", "15", "19", "18", "20", "23", "24", "25", "22", "12", "13", "17"]
court_tiers[1] = Array["Center", "18", "19", "17", "14", "15", "12", "13", "09", "10", "07", "08"]
court_tiers[2] = Array["Center", "18", "19", "17", "14", "15", "12", "13", "09", "10", "07", "08"]
court_tiers[3] = Array["14", "15", "12", "13", "09", "10", "07", "08", "Center", "18", "19", "17"]
court_tiers[4] = Array["14", "15", "12", "13", "09", "10", "07", "08", "Center", "18", "19", "17"]
court_tiers[5] = Array["19", "20"]
court_tiers[6] = Array["Center", "18", "19", "17", "14", "15", "12", "13", "09", "10", "07", "08"]

def pick_best_court(ranked_courts, available_courts)
  ranked_open_courts = Array.new
  for court in ranked_courts
    for open_court in available_courts
      if open_court.court == court
        ranked_open_courts << open_court
        break
      end
    end
  end
  ranked_open_courts
end

def pick_player(players)
  players[0]
end

for player in players
  player.login
end

me = players[0]
available_courts = me.get_available_courts

courts = []
for court_time in court_times_by_day[me.date.wday]
  if available_courts.has_key?(court_time)
    for court in pick_best_court(court_tiers[me.date.wday], available_courts[court_time])
      for player in players
        if player.can_make_reservation?(court) and player.pick_court_and_time(court)
          # reserve court
          courts << court
          log.info "Reserved " + court.to_s + " on " + player.dateStr + " for " + player.name

          available_courts[court_time].delete(court)
          break
        else
          log.debug "Unable to reserve " + court.to_s + " on " + player.dateStr + " for " + player.name
        end
      end
    end
  else
    log.debug "No available courts for " + court_time
  end
end

for player in players
  player.logout
end

courts_as_string = ''
if courts.any?
  meetup_updater = MeetupUpdater.new(cnf[:meetup])
  courts.each { |court| courts_as_string += court.to_s + " " }
  meetup_updater.update_meetup(me.date, courts_as_string)
end

smtp_info =
    begin
      date_str = "%d/%d/%d" % [me.date.month, me.date.day, me.date.year]
      subject = 'Court reservations for ' + date_str
      body = courts_as_string + "\n-------- DEBUG LOG ---------\n" +
          File.read(options[:logfile])
      mailer = SMTPGoogleMailer.new(cnf[:smtp])
      mailer.send_plain_email('oskarmellow@gmail.com',
                              'jeffnamkung@gmail.com',
                              subject, body)
    rescue
      $stderr.puts "Could not find SMTP info"
    end

