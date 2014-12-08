class Court
  attr_reader :long_name
  attr_reader :short_name

  def initialize(court)
    @court = court
    if court == 'Center' or court == 'CC'
      @long_name = 'Center Court'
      @short_name = 'CC'
    else
      @long_name = 'Court ' + court.to_s
      @short_name = 'CT' + court.to_s
    end
  end
end