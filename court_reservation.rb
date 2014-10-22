class CourtReservation
  def time
    @time
  end

  def court
    @court
  end

  def initialize(court, time)
    @court = court
    @time = time
  end
end
