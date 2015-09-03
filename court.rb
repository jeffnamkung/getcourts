class Court
  attr_reader :long_name
  attr_reader :short_name

  def initialize(court)
    if court == '7'
      @court = '07'
    elsif court == '8'
      @court = '08'
    elsif court == '9'
      @court = '09'
    else
      @court = court.to_s
    end
    if @court == 'Center' or @court == 'CC'
      @long_name = 'Center Court'
      @short_name = 'CC'
    else
      @long_name = 'Court ' + @court
      @short_name = 'CT' + @court
    end
  end
end