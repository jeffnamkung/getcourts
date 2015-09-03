require_relative 'player'

class PlayerPool
  def initialize(config, date)
    @players = []

    config.each do |player_config|
      player = Player.new(player_config, date)

      if player.days.include?(player.date.wday)
        @players << player
      end
    end
  end

  def have_players?
    not @players.empty?
  end

  def fill_reservations
    DailyReservation.reservations.each do |reservation|
      @players.each do |player|
        if reservation.filled?
          break
        end
        player.login
        player.reserve_court(reservation)
        player.logout
      end
    end
  end
end