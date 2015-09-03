require_relative 'court'

require 'set'
require 'time'

class DailyReservation
  attr_reader :start_time
  attr_reader :end_time
  attr_accessor :num_courts
  attr_reader :court_preference
  attr_reader :reserved_courts

  BLOCK_TIME = 90 * 60

  def initialize(start_time, num_courts, preferred_courts)
    @start_time = Time.parse(start_time)
    @end_time = @start_time + BLOCK_TIME

    @num_courts = num_courts
    @court_preference = []
    @reserved_courts = Set.new
    default_court_preferences = Array["Center", "09", "10", "07", "08", "19", "18", "20", "21", "14", "13", "15", "12", "23", "24", "25", "26", "16", "11", "17", "22", "17", "27"]
    if preferred_courts.kind_of?(Array)
      preferred_courts.each do |court|
        @court_preference << Court.new(court)
        default_court_preferences.delete(court)
      end
    end
    default_court_preferences.each do |court|
      @court_preference << Court.new(court)
    end
  end

  def overlaps?(time)
    end_time = time + BLOCK_TIME
    time.between?(@start_time, @end_time) or
        (end_time).between?(@start_time, @end_time)
  end

  def reserve_court(court)
    @reserved_courts.add?(court)
  end

  def filled?
    @reserved_courts.size >= @num_courts
  end

  def to_s
    to_string = "%d courts @ " % (@num_courts - @reserved_courts.size)
    to_string += @start_time.strftime('%I:%M%p')
    to_string += ' Preferring ' + @court_preference.map { |court| court.short_name }.join(", ") unless @court_preference.nil?
    to_string
  end

  @@date = nil
  @@reservations_by_time = {}

  def DailyReservation.initialize(configuration, date)
    @@date = date
    configuration[@@date.strftime("%A").to_sym].each do |time_slot|
      reservation = DailyReservation.new(time_slot[:start_time],
                                         time_slot[:num_courts],
                                         time_slot[:court])
      @@reservations_by_time[reservation.start_time] = reservation
    end
  end

  def DailyReservation.get_existing_reservations
    courts_by_time = Hash.new { |h, k| h[k]=[] }
    @@reservations_by_time.each do |time, reservation|
      reservation.reserved_courts.each do |court|
        courts_by_time[time] << court
      end
    end
    courts_by_time
  end

  def DailyReservation.reservations
    @@reservations_by_time.values
  end

  def DailyReservation.to_s
    to_string = "Daily Reservations for " + @@date.strftime("%A")
    @@reservations_by_time.values.each do |reservation|
      to_string += "\n\t" + reservation.to_s
    end
    to_string
  end
end