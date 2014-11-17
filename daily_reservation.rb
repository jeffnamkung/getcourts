require 'time'

class DailyReservation
  attr_reader :start_time
  attr_accessor :num_courts
  attr_reader :court_preference

  def initialize(time_slot)
    @start_time = Time.parse(time_slot[:start_time])
    @num_courts = time_slot[:num_courts]
    @court_preference  = Array["Center", "14", "13", "15", "12", "07", "09", "19", "18", "20", "21", "23", "24", "25", "10", "08", "26", "16", "11", "17", "22", "17", "27"]
    if time_slot.key?(:court)
      time_slot[:court].each do |court|
        @court_preference.delete_if { |ranked_court| ranked_court == court }
        @court_preference.insert(0, court)
      end
    end
  end

  def make_reservation
    @num_courts -= 1
    if @num_courts == 0
      @@reservations_by_time.delete(@start_time)
    end
  end

  @@date = Date::today + 3
  @@reservations_by_time = {}
  def DailyReservation.initialize(configuration)
    configuration[@@date.strftime("%A").to_sym].each do |time_slot|
      reservation = DailyReservation.new(time_slot)
      @@reservations_by_time[reservation.start_time] = reservation
    end
  end

  def DailyReservation.not_done?
    not @@reservations_by_time.empty?
  end

  def DailyReservation.next_reservation
    @@reservations_by_time.values.first
  end

  def to_s
    to_string =  "%d courts @ " % @num_courts
    to_string += @start_time.strftime('%I:%M%p')
    to_string += ' Preferring ' + @court_preference.join(", ") unless @court_preference.nil?
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