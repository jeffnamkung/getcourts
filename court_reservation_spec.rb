require_relative 'court_reservation'
require 'rspec'

describe CourtReservation, '#overlap?' do
  it 'should return true if overlaps with another reservation' do
    existing_reservation = CourtReservation.new('CC', Time.parse('5:30PM'))
    expect(existing_reservation.overlaps?(Time.parse('7:00PM'))).to be true
    expect(existing_reservation.overlaps?(Time.parse('7:01PM'))).to be false
    expect(existing_reservation.overlaps?(Time.parse('4:00PM'))).to be true
  end
end