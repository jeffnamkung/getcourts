require_relative 'player'

class PlayerPool
  def initialize(config, date)
    @players = []

    config.each do |player_config|
      player = Player.new(player_config, date)

      if player.days.include?(player.date.wday)
        @players << player
      else
        Log.warn player.username + " does not schedule on " + player.date.strftime('%A') + "s"
      end
    end
  end

  def have_players?
    not @players.empty?
  end

  def fill_reservations
    DailyReservation.reservations.each do |reservation|
      Log.info("Finding " + reservation.to_s)
      @players.each do |player|
        if reservation.filled?
          break
        end
        if player.can_schedule?(reservation)
          player.reserve_court(reservation)
        end
      end

      if reservation.filled?
        Log.info("Filled " + reservation.to_s)
      else
        Log.warn("Unable to fill " + reservation.to_s)
      end
    end
  end
end