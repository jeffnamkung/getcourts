require_relative 'court'
require_relative 'log'

require 'set'
require 'time'

class DailyReservation
  attr_reader :start_time
  attr_accessor :num_courts
  attr_reader :court_preference

  BLOCK_TIME = 90 * 60

  def initialize(start_time, num_courts, preferred_courts)
    @start_time = Time.parse(start_time)
    @num_courts = num_courts
    @court_preference = []
    @reserved_courts = Set.new
    default_court_preferences = Array["Center", "14", "13", "15", "12", "07", "09", "19", "18", "20", "21", "23", "24", "25", "10", "08", "26", "16", "11", "17", "22", "17", "27"]
    if preferred_courts
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
    @reserved_courts.size == @num_courts
  end

  @@date = nil
  @@reservations_by_time = {}

  def DailyReservation.remove(reservation)
    @@reservations_by_time.delete(reservation.start_time)
  end

  def DailyReservation.initialize(configuration, date)
    @@date = date
    configuration[@@date.strftime("%A").to_sym].each do |time_slot|
      reservation = DailyReservation.new(time_slot[:start_time],
                                         time_slot[:num_courts],
                                         time_slot[:court])
      @@reservations_by_time[reservation.start_time] = reservation
    end
  end

  def DailyReservation.not_done?
    @@reservations_by_time.values.each do |reservation|
      return false unless reservation.filled?
    end
    return true
  end

  def DailyReservation.next_reservation
    @@reservations_by_time.values.each do |reservation|
      return reservation unless reservation.filled?
    end
  end

  def to_s
    to_string = "%d courts @ " % @num_courts
    to_string += @start_time.strftime('%I:%M%p')
    to_string += ' Preferring ' + @court_preference.map{|court| court.short_name}.join(", ") unless @court_preference.nil?
    to_string
  end

  def DailyReservation.to_s
    to_string = "Daily Reservations for " + @@date.strftime("%A")
    @@reservations_by_time.values.each do |reservation|
      to_string += "\n\t" + reservation.to_s
    end
    to_string
  end
end