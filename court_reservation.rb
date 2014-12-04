require_relative 'court'
require 'time'

class CourtReservation
  attr_reader :start_time
  attr_reader :court

  BLOCK_TIME = 90 * 60

  def initialize(court, start_time)
    @court = Court.new(court)
    @start_time = start_time
    @end_time = start_time + BLOCK_TIME
  end

  def overlaps?(time)
    end_time = time + BLOCK_TIME
    time.between?(@start_time, @end_time) or
        (end_time).between?(@start_time, @end_time)
  end

  def to_s
    time = @start_time.strftime('%I:%M%p')
    @court.long_name + ' @ ' + time
  end
end
