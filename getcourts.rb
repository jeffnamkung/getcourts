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

  opts.on('-u', '--userfile userfile', 'users file') { |v| options[:userfile] = v }
  opts.on('-l', '--logfile logfile', 'log file') { |v| options[:logfile] = v }
  opts.on('-s', '--smtp smtpconfigfile', 'smtp configuration file') { |v| options[:smtp] = v }
  opts.on('-m', '--meetup meetupconf', 'meetup configuration file') { |v| options[:meetup] = v }
end.parse!

cnf = YAML::load_file(options[:userfile])

log = Logger.new(options[:logfile], 'daily')

players = []
for user in cnf['users']
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

def rankCourts(courts)
  rankings = Hash.new
  i = 0
  for court in courts
    rankings[i] = court
    i += 1
  end
  return rankings
end

court_tiers = Array.new
court_tiers[0] = Array["14", "15", "19", "18", "20", "23", "24", "25", "22", "12", "13", "17"]
court_tiers[1] = Array["Center", "18", "19", "17", "14", "15", "12", "13", "09", "10", "07", "08"]
court_tiers[2] = Array["Center", "18", "19", "17", "14", "15", "12", "13", "09", "10", "07", "08"]
court_tiers[3] = Array["14", "15", "12", "13", "09", "10", "07", "08", "Center", "18", "19", "17"]
court_tiers[4] = Array["14", "15", "12", "13", "09", "10", "07", "08", "Center", "18", "19", "17"]
court_tiers[5] = Array["19", "20"]
court_tiers[6] = Array["Center", "18", "19", "17", "14", "15", "12", "13", "09", "10", "07", "08"]

def pickBestCourt(rankedCourts, availableCourts)
  rankedOpenCourts = Array.new
  for court in rankedCourts
    for open_court in availableCourts
      if open_court.court == court
        rankedOpenCourts << open_court
        break
      end
    end
  end
  return rankedOpenCourts
end

def pickPlayer(players)
  players[0]
end

for player in players
  player.login()
end

me = players[0]
availableCourts = me.getAvailableCourts()

courts = []
available_courts = 'Available Courts: '
reserved_courts = 'Reserved Courts: '
unreserved_courts = 'Errors: '
for court_time in court_times_by_day[player.date.wday]
  if not availableCourts.has_key?(court_time)
    result = "No available courts for " + court_time
    unreserved_courts = unreserved_courts + "\n" + result
    log.debug result
  else
    for court in pickBestCourt(court_tiers[player.date.wday], availableCourts[court_time])
      available_courts = available_courts + "\n" + court.to_s
      for player in players
        if player.canMakeReservation?(court) and player.pickCourtAndTime(court)
          # reserve court
          courts << court
          log.info "Reserved " + court.to_s + " on " + player.dateStr + " for " + player.name
          reserved_courts = reserved_courts + "\n" + result
          log.debug result

          availableCourts[court_time].delete(court)
          break
        else
          result = "Unable to reserve " + court.to_s + " on " + player.dateStr + " for " + player.name
          unreserved_courts = unreserved_courts + "\n" + result
          log.debug result
        end
      end
    end
  end
end

for player in players
  player.logout()
end

date_str = "%d/%d/%d" % [me.date.month, me.date.day, me.date.year]
subject = 'Court reservations for ' + date_str
body = reserved_courts + "\n" + available_courts + "\n" + unreserved_courts

if not courts.empty?
  meetup_conf = YAML::load_file(options[:meetup])
  meetup_updater = MeetupUpdater.new(meetup_conf[:apikey],
                                     meetup_conf[:member_id],
                                     meetup_conf[:group_id],
                                     meetup_conf[:venue_id])
  courts_as_string = ''
  courts.each { |court| courts_as_string += court.to_s + " " }
  meetup_updater.update_meetup(me.date, courts_as_string)
end

smtp_info =
    begin
      mailer = SMTPGoogleMailer.new(YAML.load_file(options[:smtp]))
      body += "\n-------- DEBUG LOG ---------\n" +  File.read(options[:logfile])
      mailer.send_plain_email('oskarmellow@gmail.com', 'jeffnamkung@gmail.com', subject, body)
    rescue
      $stderr.puts "Could not find SMTP info"
    end

