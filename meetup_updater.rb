require 'pp'
require 'rmeetup'

module RMeetup
  module Poster
    class Event < Base
      attr_accessor :id
      def initialize
        @type = :event
      end

      # Turn the result hash into a Comment Class
      def format_result(result)
        RMeetup::Type::Event.new(result)
      end

      protected
      def base_url
        "https://api.meetup.com/2/#{@type}/#{@id}/"
      end
    end
  end

  class Client
    def post(type, id, options = {})
      poster = RMeetup::Poster.for(type)
      poster.id = id
      poster.post options.merge(auth)
    end
  end
end

class MeetupUpdater
  def initialize(api_key, member_id, group_id, venue_id)
    @client = RMeetup::Client.new do |config|
      config.api_key = api_key
    end

    @event_options = {
      :member_id => member_id,
      :group_id => group_id,
      :venue.id => venue_id
    }
  end

  def update_meetup(date, courts)
    @event_options[:time] = "%d,%d" % [date.to_time.to_i * 1000, (date + 1).to_time.to_i * 1000]

    @client.fetch(:events, @event_options).each do |result|
      # Do something with the result
      client.post(:event, result.event['id'], {
          :how_to_find_us =>
              result.event.key?('how_to_find_us') ?
                  courts + ". " + result.how_to_find_us : courts
      })
      break
    end
  end
end