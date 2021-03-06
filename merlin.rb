# Hide fugly procedural database access code in here!

require Pathname(__dir__).join('lib', 'guest.rb')
require Pathname(__dir__).join('lib', 'itinerary.rb')

module Merlin
  Invoice = Struct.new(:id, :contact_id, :contact_email_address)
  LockCombination = Struct.new(:value, :valid_from, :valid_to)

  def self.pretty_structs(structs)
    "\n\t#{structs.map(&:to_h).join("\n\t")}"
  end

  def self.get_invoices_with_stays_beginning(db:, date:)
    lambda do
      invoices = []

      begin
        conn = PG::connect(db)

        res = conn.exec_params('SELECT * FROM get_invoices_with_stays_beginning($1::date)', [date.to_date])

        invoices += res.map(&ROW_TO_INVOICE)
      rescue PG::Error => e
        STDERR.puts "An error of type #{e.class} occurred at #{fnow} while attempting to get invoices from beginning.\n#{e.message}"
        raise
      ensure
        conn&.close
      end
       
      STDOUT.puts "#{fnow} - Invoices found with stays beginning #{date}: #{pretty_structs(invoices)}"

      invoices
    end
  end

  def self.get_invoices_with_stays_ending(db:, date:)
    lambda do
      invoices = []

      begin
        conn = PG::connect(db)

        res = conn.exec_params('SELECT * FROM get_invoices_with_stays_ending($1::date)', [date.to_date])

        invoices += res.map(&ROW_TO_INVOICE)
      rescue PG::Error => e
        STDERR.puts "An error of type #{e.class} occurred at #{fnow} while attempting to get invoices from ending.\n#{e.message}"
        raise
      ensure
        conn&.close
      end
      
      STDOUT.puts "#{fnow} - Invoices found with stays ending #{date}: #{pretty_structs(invoices)}}"

      invoices
    end
  end

  def self.get_reservations_for_invoice(db:, invoice_id:)
    lambda do
      reservations = []

      begin
        conn = PG::connect(db)

        res = conn.exec_params('SELECT * FROM get_itinerary_for_invoice($1::integer)', [invoice_id.to_i])

        reservations += ROWS_TO_RESERVATIONS.call(res)

      rescue PG::Error => e
        STDERR.puts "An error of type #{e.class} occurred at #{fnow} while attempting to get itinerary for invoice.\n#{e.message}"
        raise
      ensure
        conn&.close
      end

      reservations
    end
  end

  def self.get_lock_combinations_for_date
    proc do |db, facility_code, date|
      combinations = []

      begin
        conn = PG::connect(db)

        res = conn.exec_params('SELECT * FROM get_lock_combinations_for_stay($1::text, $2::date)', [facility_code, date])

        combinations += res.map(&ROW_TO_COMBINATION)
      rescue PG::Error => e
        STDERR.puts "An error of type #{e.class} occurred at #{fnow} while attempting to get lock combinations.\n#{e.message}"
        raise
      ensure
        conn&.close
      end

      combinations
    end
  end

  def self.get_itineraries_from_delay(db:, delay:)
    lambda do
      search_date = Date.today + delay.to_i

      calls = []
      invoices = []
      itineraries = []

      calls << get_invoices_with_stays_beginning(db: db, date: search_date) if delay.positive?
      calls << get_invoices_with_stays_ending(db: db, date: search_date) if delay.negative?
      calls += [get_invoices_with_stays_ending(db: db, date: search_date), get_invoices_with_stays_ending(db: db, date: search_date)] if delay.zero?

      calls.each do |proc|
        invoices += proc.call
      end

      invoices.map do |invoice| 
        Itinerary.new(guest: Guest.new(email: Guest::EmailAddress.new(invoice.contact_email_address)), reservations: get_reservations_for_invoice(db: db, invoice_id: invoice.id).call) 
      end
    end
  end

  def self.fnow
    now.strftime(DATE_FORMAT)
  end

  private

  DATE_FORMAT = '%H:%M:%S %Y-%m-%d'.freeze

  ROW_TO_INVOICE = proc { |row| Invoice.new(row['invoice_id'].to_i, row['contact_id'].to_i, row['contact_email_address']) }

  ROW_TO_COMBINATION = proc { |row| LockCombination.new(row['combination'], Date.parse(row['valid_from']), Date.parse(row['valid_until'])) } 

  ROW_TO_BOOKING = proc { |row| Itinerary::Booking.new(Date.parse(row['stay_date']), row['no_users'].to_i) }

  ROWS_TO_RESERVATIONS = proc do |rows|

    grouped_bookings = rows.group_by { |row| Itinerary::Facility.new(row['facility_code'], row['facility_name']) }
    grouped_bookings.map do |key, value|
      Itinerary::Reservation.new(key, value.map(&ROW_TO_BOOKING))
    end

  end
  
  def self.now
    Time::now
  end
end
