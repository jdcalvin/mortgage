require 'pry'
require 'finance'
require 'colorize'

class Mortgage

  include Finance

  attr_reader :apr, :rate, :amortization, :value, :duration

  attr_accessor :loan_amount

  def initialize(apr:, loan_amount:, duration:, value:)
    @apr = APR.new(apr)
    @loan_amount = loan_amount
    @duration = duration
    @rate = Rate.new(@apr.normalized_percent, :apr, :duration => duration)
    @amortization = Amortization.new(@loan_amount, @rate)
    @value = value
  end

  def self.current
    self.new(apr: CURRENT_APR, loan_amount: CURRENT_LOAN_AMOUNT, duration: CURRENT_DURATION, value: CURRENT_VALUE)
  end

  #

  def self.refi
    self.new(apr: REFI_APR, loan_amount: REFI_LOAN_AMOUNT, duration: REFI_DURATION, value: REFI_VALUE)
  end

  def run(years: nil, payments: nil, no_table: false, extra: nil)
    total_payments = years ? years * 12 : duration
    reset!(total_payments)
      
    # rebuild amortization, extra and pmi could be 0 
    @amortization = loan_amount.amortize(rate) {|x| x.payment - (extra.to_f) }
    
    struct = schedule
    if years
      end_year = DateTime.now.year + years
      struct = struct.select do |x| 
        (x.month.year < end_year) || (x.month.year == end_year && x.month.number <= Month.current)
      end
    end
    if payments
      struct = struct.select {|x| x.number <= payments}
    end

    if no_table
      t = ::Terminal::Table.new do |t|
        t.headings = Row.header(apr)
        t.add_row struct.last.print
      end
      return puts t
    end
    puts table(struct)
  end

  private

  def reset!(total_rows)
    @struct = nil
    Row.loan_amount = loan_amount
    Row.purchase_price = value
    Row.total_rows = total_rows
  end

  def schedule
    return @struct if @struct
    s = []
      Month.get_range(amortization.payments.count).each_with_index do |month, i|
        last_month = s[i-1]
        interest_payment = amortization.interest[i]
        payment = amortization.payments[i]
        row = Row.new(month: month, number: i+1, payment: payment.abs, interest_payment: interest_payment)
        row.calculate_total_paid!(last_month)
        s << row
      end
    return @struct = s
  end

  def table(struct)
    ::Terminal::Table.new do |t|
      t.headings = Row.header(apr)
      t.rows = struct.map(&:print)
      t.add_separator
      t.add_row Row.header(apr)
    end
  end

  class Row

    attr_reader :month, :number, :payment, :interest_payment
    attr_accessor :total_interest_paid, :total_principal_paid, :principal_payment, :remaining_balance, :total_paid

    def initialize(month:, number:, payment:, interest_payment:)
      @month = month
      @number = number
      @payment = payment
      @interest_payment = interest_payment
    end

    def calculate_total_paid!(prior)
      self.principal_payment = payment.abs - interest_payment
      self.total_interest_paid = (prior ? prior.total_interest_paid : 0) + interest_payment
      self.total_principal_paid = (prior ? prior.total_principal_paid : 0) + principal_payment
      self.remaining_balance = loan_amount - total_principal_paid
      self.total_paid = total_interest_paid + total_principal_paid
    end

    def self.loan_amount=(amt)
      @@loan_amount = amt
    end

    def self.total_rows=(n)
      @@total_rows = n
    end

    def self.purchase_price=(amt)
      @@purchase_price = amt
    end

    def self.header(apr)
      [
        "Rate @ #{apr.percent.to_s}%".colorize(:cyan).bold,
        'Monthly',
        'Interest',
        'Principal',
        'Total Int.',
        'Total Prin.',
        'Total',
        'Remaining',
        'LTV',
      ]
    end

    def row_num
      max_size = @@total_rows.to_s.size
      pad = max_size - number.to_s.size
      "#{number}.#{" " * pad}"
    rescue
      binding.pry
    end

    def response
      {
        num:                  "#{row_num} #{month.short_name} #{month.year}",
        monthly_payment:      to_currency(payment),
        interest_payment:     to_currency(interest_payment),
        principal_payment:    to_currency(principal_payment),
        total_interest_paid:  to_currency(total_interest_paid),
        total_principal_paid: to_currency(total_principal_paid),
        total_paid:           to_currency(total_paid),
        remaining_balance:    to_currency(remaining_balance),
        ltv:                  to_percent(ltv),
      }
    end

    def print
      response.values.map {|x| highlight(x)}
    end

    private


    def ltv
      (remaining_balance / purchase_price)
    end

    def loan_amount
      @@loan_amount
    end

    def highlight(val)
      if ltv <= 0.8 && ltv > 0.79
        val.to_s.colorize(:yellow)
      elsif number % 12 == 0
        val.to_s.colorize(:cyan)
      else
        val
      end
    end

    def purchase_price
      @@purchase_price
    end

    def to_currency(number=0)
      "$#{number.round(2)}"
    end

    def to_percent(number=0)
      "#{(number * 100).round(2)}%"
    end

  end

  class APR
    attr_reader :percent, :normalized_percent

    def initialize(percent)
      @percent = percent
      @normalized_percent = percent.to_f / 100
    end

    def daily_apr
      @daily_apr ||= @normalized_percent / 365
    end
  end
end
