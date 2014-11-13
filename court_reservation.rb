class CourtReservation
  attr_reader :time
  attr_reader :court

  def initialize(court, time)
    @court = court
    @time = time
  end

  def to_s
    if court == "Center"
      "Center Court @ " + time
    else
      "Court " + court + " @ " + time
    end
  end
end
