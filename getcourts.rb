#!/usr/local/bin/ruby

require_relative 'player'
require_relative 'court_reservation'

require 'logger'
require 'optparse'
require 'watir-webdriver'
require 'set'
require 'time'
require 'yaml'
require 'rmeetup'
require 'net/smtp'
require 'tlsmail'

class SMTPGoogleMailer
  attr_accessor :smtp_info

  def send_plain_email from, to, subject, body
    mailtext = <<EOF
From: #{from}
To: #{to}
Subject: #{subject}

    #{body}
EOF
    send_email from, to, mailtext
  end

  def send_attachment_email from, to, subject, body, attachment
# Read a file and encode it into base64 format
    begin
      filecontent = File.read(attachment)
      encodedcontent = [filecontent].pack("m")   # base64
    rescue
      raise "Could not read file #{attachment}"
    end

    marker = (0...50).map{ ('a'..'z').to_a[rand(26)] }.join
    part1 =<<EOF
From: #{from}
To: #{to}
Subject: #{subject}
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary=#{marker}
--#{marker}
EOF

# Define the message action
    part2 =<<EOF
Content-Type: text/plain
Content-Transfer-Encoding:8bit

#{body}
--#{marker}
EOF

# Define the attachment section
    part3 =<<EOF
Content-Type: multipart/mixed; name=\"#{File.basename(attachment)}\"
Content-Transfer-Encoding:base64
Content-Disposition: attachment; filename="#{File.basename(attachment)}"

#{encodedcontent}
--#{marker}--
EOF

    mailtext = part1 + part2 + part3

    send_email from, to, mailtext
  end

  private

  def send_email from, to, mailtext
    begin
      Net::SMTP.enable_tls(OpenSSL::SSL::VERIFY_NONE)
      Net::SMTP.start(@smtp_info[:smtp_server], @smtp_info[:port], @smtp_info[:helo], @smtp_info[:username], @smtp_info[:password], @smtp_info[:authentication]) do |smtp|
        smtp.send_message mailtext, from, to
      end
    rescue => e
      raise "Exception occured: #{e} "
      exit -1
    end
  end
end

def send_plain_email from, to, subject, body
  mailtext = <<EOF
From: #{from}
To: #{to}
Subject: #{subject}

  #{body}
EOF
  send_email from, to, mailtext
end

#start_date = (Date.today + 3).to_time.to_i * 1000
#end_date = (Date.today + 4).to_time.to_i * 1000
#puts "#{start_date},#{end_date}"
#
#RMeetup::Client.api_key = "324c5b977b10602306351385ea"
#results = RMeetup::Client.fetch(:events, {
#    :time => "#{start_date},#{end_date}",
#    :member_id => 7865492,
#    :group_id => 1619561,
#})
#puts results.size
#results.each do |result|
#  # Do something with the result
#  puts result.id
#  puts result.name
#  puts result.description
#  puts result.how_to_find_us
#  puts "# attendees: " + result.yes_rsvp_count.to_s
#  puts Time.at(result.time/1000).strftime("%m/%d/%Y %I:%M:%p")
#  # puts "Time: " + result.time
#end

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: getcourts.rb [options]"

  opts.on('-u', '--userfile userfile', 'users file') { |v| options[:userfile] = v }
  opts.on('-l', '--logfile logfile', 'log file') { |v| options[:logfile] = v }
  opts.on('-s', '--smtp smtpconfigfile', 'smtp configuration file') { |v| options[:smtp] = v }
end.parse!

cnf = YAML::load_file(options[:userfile])

smtp_info =
    begin
      YAML.load_file(options[:smtp])
    rescue
      $stderr.puts "Could not find SMTP info"
      exit -1
    end

mailer = SMTPGoogleMailer.new
mailer.smtp_info = smtp_info

players = []
for user in cnf['users']
  players << Player.new(user)
end

log = Logger.new(options[:logfile], 'daily')

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

available_courts = 'Available Courts: '

reserved_courts = 'Reserved Courts: '
unreserved_courts = 'Errors: '
for court_time in court_times_by_day[player.date.wday]
  if not availableCourts.has_key?(court_time)
    result = "No available courts for " + court_time
    unreserved_courts = unreserved_courts + "\n" + result
    puts result
    log.debug result
  else
    for court in pickBestCourt(court_tiers[player.date.wday], availableCourts[court_time])
      available_courts = available_courts + "\n" + court.to_s
      for player in players
        if player.canMakeReservation?(court) and player.pickCourtAndTime(court)
          # reserve court
          result = "Reserved " + court.to_s + " on " + player.dateStr + " for " + player.name
          reserved_courts = reserved_courts + "\n" + result
          puts result
          log.debug result

          availableCourts[court_time].delete(court)
          break
        else
          result = "Unable to reserve " + court.to_s + " on " + player.dateStr + " for " + player.name
          unreserved_courts = unreserved_courts + "\n" + result
          puts result
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
mailer.send_plain_email 'oskarmellow@gmail.com', 'jeffnamkung@gmail.com', subject, body
mailer.send_plain_email 'oskarmellow@gmail.com', 'dave@ironmantennis.com', subject, body

