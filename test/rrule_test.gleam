import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleam/time/duration
import gleam/time/timestamp
import gleeunit
import gleeunit/should
import rrule.{
  Daily, Friday, Monday, Monthly, Weekly, Yearly, from_string,
  generate_occurrences, get_frequency, get_interval, has_end_condition, is_valid,
  new, next_occurrence, to_string, weekday_occurrence,
  weekday_occurrence_with_number, with_by_day, with_by_month, with_count,
  with_interval, with_until,
}

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn new_rrule_test() {
  let rule = new(Daily)
  rule.frequency
  |> should.equal(Daily)
}

pub fn to_string_daily_test() {
  new(Daily)
  |> to_string()
  |> should.equal("FREQ=DAILY")
}

pub fn to_string_weekly_test() {
  new(Weekly)
  |> to_string()
  |> should.equal("FREQ=WEEKLY")
}

pub fn to_string_with_count_test() {
  new(Daily)
  |> with_count(10)
  |> to_string()
  |> should.equal("FREQ=DAILY;COUNT=10")
}

pub fn to_string_with_interval_test() {
  new(Weekly)
  |> with_interval(2)
  |> to_string()
  |> should.equal("FREQ=WEEKLY;INTERVAL=2")
}

pub fn to_string_with_by_day_test() {
  new(Weekly)
  |> with_by_day([weekday_occurrence(Monday), weekday_occurrence(Friday)])
  |> to_string()
  |> should.equal("FREQ=WEEKLY;BYDAY=MO,FR")
}

pub fn to_string_with_by_day_occurrence_test() {
  new(Monthly)
  |> with_by_day([weekday_occurrence_with_number(Monday, 1)])
  |> to_string()
  |> should.equal("FREQ=MONTHLY;BYDAY=1MO")
}

pub fn to_string_with_by_month_test() {
  new(Yearly)
  |> with_by_month([1, 6, 12])
  |> to_string()
  |> should.equal("FREQ=YEARLY;BYMONTH=1,6,12")
}

pub fn to_string_complex_test() {
  new(Weekly)
  |> with_count(20)
  |> with_interval(2)
  |> with_by_day([weekday_occurrence(Monday), weekday_occurrence(Friday)])
  |> to_string()
  |> should.equal("FREQ=WEEKLY;COUNT=20;INTERVAL=2;BYDAY=MO,FR")
}

pub fn from_string_daily_test() {
  from_string("FREQ=DAILY")
  |> should.be_ok()
  |> get_frequency()
  |> should.equal(Daily)
}

pub fn from_string_with_count_test() {
  let assert Ok(rule) = from_string("FREQ=DAILY;COUNT=5")
  rule.count
  |> should.equal(Some(5))
}

pub fn from_string_with_interval_test() {
  let assert Ok(rule) = from_string("FREQ=WEEKLY;INTERVAL=3")
  rule.interval
  |> should.equal(Some(3))
}

pub fn from_string_with_by_day_test() {
  let assert Ok(rule) = from_string("FREQ=WEEKLY;BYDAY=MO,FR")
  rule.by_day
  |> list.length()
  |> should.equal(2)
}

pub fn from_string_complex_test() {
  let assert Ok(rule) =
    from_string("FREQ=WEEKLY;COUNT=10;INTERVAL=2;BYDAY=MO,WE,FR")
  rule.frequency |> should.equal(Weekly)
  rule.count |> should.equal(Some(10))
  rule.interval |> should.equal(Some(2))
  rule.by_day |> list.length() |> should.equal(3)
}

pub fn from_string_invalid_freq_test() {
  from_string("FREQ=INVALID")
  |> should.be_error()
}

pub fn from_string_missing_freq_test() {
  from_string("COUNT=5")
  |> should.be_error()
}

pub fn roundtrip_test() {
  let original =
    new(Weekly)
    |> with_count(10)
    |> with_interval(2)
    |> with_by_day([weekday_occurrence(Monday), weekday_occurrence(Friday)])

  let rrule_string = to_string(original)
  let assert Ok(parsed) = from_string(rrule_string)

  parsed.frequency |> should.equal(original.frequency)
  parsed.count |> should.equal(original.count)
  parsed.interval |> should.equal(original.interval)
  parsed.by_day |> list.length() |> should.equal(2)
}

pub fn is_valid_normal_test() {
  new(Daily)
  |> with_count(10)
  |> is_valid()
  |> should.be_true()
}

pub fn get_interval_default_test() {
  new(Daily)
  |> get_interval()
  |> should.equal(1)
}

pub fn get_interval_custom_test() {
  new(Daily)
  |> with_interval(3)
  |> get_interval()
  |> should.equal(3)
}

pub fn has_end_condition_with_count_test() {
  new(Daily)
  |> with_count(10)
  |> has_end_condition()
  |> should.be_true()
}

pub fn has_end_condition_without_end_test() {
  new(Daily)
  |> has_end_condition()
  |> should.be_false()
}

pub fn to_string_with_until_test() {
  let until_time = timestamp.parse_rfc3339("2024-12-31T23:59:59Z")
  let assert Ok(time) = until_time

  let result =
    new(Daily)
    |> with_until(time)
    |> to_string()

  result
  |> string.starts_with("FREQ=DAILY;UNTIL=")
  |> should.be_true()
}

pub fn from_string_with_until_test() {
  let assert Ok(rule) = from_string("FREQ=DAILY;UNTIL=2024-12-31T23:59:59Z")
  rule.until
  |> should.not_equal(None)
}

pub fn with_until_clears_count_test() {
  let until_time = timestamp.parse_rfc3339("2024-12-31T23:59:59Z")
  let assert Ok(time) = until_time

  let rule =
    new(Daily)
    |> with_count(10)
    |> with_until(time)

  rule
  |> is_valid()
  |> should.be_true()

  rule.count
  |> should.equal(None)
}

pub fn next_occurrence_daily_test() {
  let start_time = timestamp.parse_rfc3339("2024-01-01T10:00:00Z")
  let assert Ok(start) = start_time

  let rule = new(Daily)

  let next = next_occurrence(rule, start)
  case next {
    Some(time) -> {
      let result = timestamp.to_rfc3339(time, duration.seconds(0))
      result
      |> string.contains("2024-01-02T10:00:00")
      |> should.be_true()
    }
    None -> should.fail()
  }
}

pub fn next_occurrence_with_until_test() {
  let start_time = timestamp.parse_rfc3339("2024-12-30T10:00:00Z")
  let until_time = timestamp.parse_rfc3339("2024-12-31T00:00:00Z")
  let assert Ok(start) = start_time
  let assert Ok(until) = until_time

  let rule = new(Daily) |> with_until(until)

  next_occurrence(rule, start)
  |> should.equal(None)
}

pub fn generate_occurrences_test() {
  let start_time = timestamp.parse_rfc3339("2024-01-01T10:00:00Z")
  let assert Ok(start) = start_time

  let rule = new(Daily) |> with_count(3)

  let occurrences = generate_occurrences(rule, start, None)

  occurrences
  |> list.length()
  |> should.equal(3)
}
