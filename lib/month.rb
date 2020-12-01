class Month
  require 'date'
  attr_reader :number, :year

  SCHEDULED_PAYMENT_DAY = 01 #Adjust for normally scheduled payment
  DAYS_IN_MONTH = { 1 =>  {days: 31, name: 'January'},
                    2 =>  {days: 28, name: 'February'}, # I'm too lazy to consider leap years right now
                    3 =>  {days: 31, name: 'March'},
                    4 =>  {days: 30, name: 'April'},
                    5 =>  {days: 31, name: 'May'},
                    6 =>  {days: 30, name: 'June'},
                    7 =>  {days: 31, name: 'July'},
                    8 =>  {days: 31, name: 'August'},
                    9 =>  {days: 30, name: 'September'},
                    10 => {days: 31, name: 'October'},
                    11 => {days: 30, name: 'November'},
                    12 => {days: 31, name: 'December'}}

  RANGE = DAYS_IN_MONTH.keys

  START_DATE_TIME = DateTime.now
  def initialize(number=nil)
    @year = 0
    @number = number || START_DATE_TIME.month
  end

  def total_days
    DAYS_IN_MONTH[number][:days]
  end

  def year=(y)
    @year = y
  end

  def name
    DAYS_IN_MONTH[number][:name]
  end

  def short_name
    name[0..2]
  end

  def self.months_since_date(date1, date2=Time.now)
    (date2.year * 12 + date2.month) - 
    (date1.year * 12 + date1.month)
  end

  def self.get_range(count)
    
    select_months = []
    month_array = []
    month_array += RANGE while month_array.length < count
    current_year = START_DATE_TIME.year

    count.times do |x|
      m_num = current + (x - 1)
      month = Month.new(month_array[m_num])
      month.year = current_year
      select_months << month
      
      current_year += 1 if month.number == 12
    end
    select_months
  end

  def self.current # Month ends on date the scheduled payment is due and begins on the next day
    month = START_DATE_TIME.month
    START_DATE_TIME.day >= SCHEDULED_PAYMENT_DAY ? month+1 : month
  end
end