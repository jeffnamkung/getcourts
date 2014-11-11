class CourtReservation
  def time
    @time
  end

  def court
    @court
  end

  def to_s
    if court == "Center"
      "Center Court @ " + time
    else
      "Court " + court + " @ " + time
    end
  end

  def initialize(court, time)
    @court = court
    @time = time
  end
end
