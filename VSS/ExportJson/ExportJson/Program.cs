using ExportJson.Models;
using RestSharp;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;

namespace ExportJson
{
    static class Program
    {
        static string exportPath;
        static int months = 6;
        static bool asParallel = false;
        static WeekendExcursionSettings weekendExcursionSettings;
        static void Main(string[] args)
        {
            System.Net.ServicePointManager.DefaultConnectionLimit = Environment.ProcessorCount * 12;
            NLog.Logger logger = NLog.LogManager.GetLogger("Main");
            Stopwatch sw = new Stopwatch();
            sw.Start();
            logger.Info("Start {0}", String.Join(" ", args));
            try
            {
                string[] origin = null;
                #region parse parameters
                for (int i = 0; i < args.Length; i++)
                {
                    if (args[i] == "-Months")
                    {
                        months = int.Parse(args[i + 1]);
                    }
                    if (args[i] == "-Origin")
                    {
                        origin = args[i + 1].Split(','); ;
                    }
                    if (args[i] == "-AsParallel")
                    {
                        asParallel = true;
                    }
                }
                logger.Info($"months={months}");
                if (origin == null)
                {
                    throw new ArgumentException("Origin not specified");
                }
                origin.ToList().ForEach(o => logger.Info($"origin={o}"));
                logger.Info($"asParallel={asParallel}");
                #endregion

                #region Culture
                var culture = (System.Globalization.CultureInfo)System.Threading.Thread.CurrentThread.CurrentCulture.Clone();
                culture.DateTimeFormat.ShortDatePattern = "dd/MM/yyyy";
                System.Threading.Thread.CurrentThread.CurrentCulture = culture;
                System.Threading.Thread.CurrentThread.CurrentUICulture = culture;
                #endregion

                #region WeekendExcursionSettings
                weekendExcursionSettings = new WeekendExcursionSettings()
                {
                    OutboundEarliestFriday = 17,
                    OutboundLatestSaturday = 13,
                    InboundEarliestSunday = 18,
                    InboundLatestMonday = 9
                };
                #endregion

                #region export path
                var date = DateTime.Now.ToString("yyyyMMdd");
                exportPath = Path.Combine(Path.GetTempPath(), date);
                logger.Info($"exportPath={exportPath}");

                if (!Directory.Exists(exportPath))
                {
                    Directory.CreateDirectory(exportPath);
                }
                logger.Debug($"{exportPath} is ready");
                #endregion


                #region get schedules
                var scheduleTasks = origin.Select(o =>
                {
                    Func<IEnumerable<Schedule>> func = () => GetRyanAirSchedule(o);
                    return new Task<IEnumerable<Schedule>>(func);
                }).ToList();
                if (asParallel)
                {
                    scheduleTasks.ForEach(t => t.Start());
                    Task.WaitAll(scheduleTasks.ToArray());
                }
                else
                {
                    scheduleTasks.ForEach(t => t.RunSynchronously());
                }
                var allSchedules = new List<Schedule>();
                logger.Debug("Aggregating schedules");
                scheduleTasks.ForEach(t =>
                {
                    if (t.Result == null)
                    {
                        return;
                    }
                    allSchedules.AddRange(t.Result);
                });
                logger.Debug($"allSchedules.Count={allSchedules.Count}");
                #endregion

                #region export
                var exportTasks = allSchedules.Select(o =>
                {
                    return new Task(() => Export(o));
                }).ToList();
                if (asParallel)
                {
                    exportTasks.ForEach(t => t.Start());
                    Task.WaitAll(exportTasks.ToArray());
                }
                else
                {
                    exportTasks.ForEach(t => t.RunSynchronously());
                }
                #endregion
            }
            catch (Exception ex)
            {
                logger.Error(ex);
            }
            finally
            {
                sw.Stop();
                logger.Info($"Finished in {sw.ElapsedMilliseconds}ms");
            }

#if DEBUG
            Console.ReadLine();
#endif
        }
        private static IEnumerable<Flight> GetRyanAirFlights(string origin, string destination, DateTime dateOut, int flexDaysOut, DateTime dateIn, int flexDaysIn)
        {
            NLog.Logger logger = NLog.LogManager.GetLogger($"GetRyanAirFlights ({origin}-{destination} {dateOut.ToShortDateString()})");
            Stopwatch sw = new Stopwatch();
            sw.Start();
            logger.Debug("Start");
            try
            {
                var client = new RestClient(@"https://desktopapps.ryanair.com/en-gb/availability");
                var request = new RestRequest(Method.GET);
                request.IncreaseNumAttempts();
                request.IncreaseNumAttempts();

                request.AddQueryParameter("Origin", origin);
                request.AddQueryParameter("Destination", destination);
                request.AddQueryParameter("DateOut", dateOut.ToString("yyyy -MM-dd"));
                request.AddQueryParameter("DateIn", dateIn.ToString("yyyy -MM-dd"));
                request.AddQueryParameter("RoundTrip", true.ToString());
                request.AddQueryParameter("FlexDaysOut", flexDaysOut.ToString());
                request.AddQueryParameter("FlexDaysIn", flexDaysIn.ToString());
                var rootObject = client.Execute<Models.FromJson.RootObject>(request).Data;
                var ryanAirFlights = new List<RyanAirFlight>();
                foreach (var trip in rootObject.trips)
                {
                    foreach (var date in trip.dates)
                    {
                        foreach (var flight in date.flights)
                        {
                            if (flight.regularFare != null)
                            {
                                ryanAirFlights.Add(new RyanAirFlight()
                                {
                                    Origin = trip.origin,
                                    Destination = trip.destination,
                                    Date = DateTime.Parse(date.dateOut),
                                    FlightNumber = flight.flightNumber,
                                    From = DateTime.Parse(flight.time[0]),
                                    To = DateTime.Parse(flight.time[1]),
                                    RegularFare=flight.regularFare.fares.First(f=>f.type=="ADT").amount
                                });
                            }
                            else
                            {
                                logger.Warn("Regular fare was null");
                            }
                        }
                    }
                }
                Func<DateTime, bool> isFridayValid = d =>
                {
                    return d.DayOfWeek == DayOfWeek.Friday && d.Hour >= weekendExcursionSettings.OutboundEarliestFriday;
                };
                Func<DateTime, bool> isSaturdayValid = d =>
                {
                    return d.DayOfWeek == DayOfWeek.Saturday && d.Hour < weekendExcursionSettings.OutboundLatestSaturday;
                };
                Func<DateTime, bool> isSundayValid = d =>
                {
                    return d.DayOfWeek == DayOfWeek.Sunday && d.Hour >= weekendExcursionSettings.InboundEarliestSunday;
                };
                Func<DateTime, bool> isMondayValid = d =>
                {
                    return d.DayOfWeek == DayOfWeek.Saturday && d.Hour < weekendExcursionSettings.InboundEarliestSunday;
                };

                var validOutbound = ryanAirFlights.Where(f => f.Origin == origin && (isFridayValid(f.From) || isSaturdayValid(f.To))).AsEnumerable();
                var validInbound = ryanAirFlights.Where(f => f.Origin == destination && (isSundayValid(f.From) || isMondayValid(f.To))).AsEnumerable();
                if (validOutbound.Count() == 0 || validInbound.Count() == 0)
                {
                    return null;
                }
                var flights = new List<Flight>();
                foreach (var outbound in validOutbound)
                {
                    foreach (var inbound in validInbound)
                    {
                        flights.Add(new Flight()
                        {
                            Origin = origin,
                            Destination = destination,
                            Friday = dateOut,
                            OutboundFrom = outbound.From,
                            OutboundTo = outbound.To,
                            InboundFrom = inbound.From,
                            InboundTo = inbound.To,
                            RegularFare = outbound.RegularFare + inbound.RegularFare
                        });
                    }
                }
                return flights;
            }
            catch (Exception ex)
            {
                logger.Error(ex);
                return null;
            }
            finally
            {
                sw.Stop();
                logger.Debug($"Finished in {sw.ElapsedMilliseconds}ms");
            }
        }
        private static IEnumerable<Schedule> GetRyanAirSchedule(string origin)
        {
            NLog.Logger logger = NLog.LogManager.GetLogger($"GetRyanAirSchedule ({origin})");
            Stopwatch sw = new Stopwatch();
            sw.Start();
            logger.Debug("Start");
            try
            {
                var client = new RestClient($"https://api.ryanair.com/timetable/3/schedules/{origin}/periods");
                var request = new RestRequest(Method.GET);
                request.IncreaseNumAttempts();
                request.IncreaseNumAttempts();
                var json = client.Execute(request).Content;
                dynamic expandoObject = Newtonsoft.Json.JsonConvert.DeserializeObject<System.Dynamic.ExpandoObject>(json, new Newtonsoft.Json.Converters.ExpandoObjectConverter());
                List<Schedule> schedules = new List<Schedule>();

                foreach (KeyValuePair<string, object> kvp in expandoObject)
                {
                    dynamic value = (System.Dynamic.ExpandoObject)kvp.Value;
                    schedules.Add(new Schedule()
                    {
                        Origin = origin,
                        Destination = kvp.Key,
                        FirstFlightDate = DateTime.Parse(value.firstFlightDate),
                        LastFlightDate = DateTime.Parse(value.lastFlightDate)
                    });
                }
                return schedules;
            }
            catch (Exception ex)
            {
                logger.Error(ex);
                return null;
            }
            finally
            {
                sw.Stop();
                logger.Debug($"Finished in {sw.ElapsedMilliseconds}ms");
            }
        }
        private static void Export(Schedule schedule)
        {
            NLog.Logger logger = NLog.LogManager.GetLogger($"Export ({schedule.Origin}-{schedule.Destination})");
            Stopwatch sw = new Stopwatch();
            sw.Start();
            logger.Info("Start");
            var fileName = $"{schedule.Origin} - {schedule.Destination}.json";
            logger.Debug($"fileName={fileName}");
            var filePath = Path.Combine(exportPath, fileName);
            logger.Debug($"filePath={filePath}");
            try
            {
                var fromDate = DateTime.Now.Date;
                if (fromDate < schedule.FirstFlightDate)
                {
                    fromDate = schedule.FirstFlightDate;
                }
                var toDate = DateTime.Now.AddMonths(months).Date;
                if (toDate > schedule.LastFlightDate)
                {
                    toDate = schedule.LastFlightDate;
                }
                var firstFriday = fromDate;
                switch (fromDate.DayOfWeek)
                {
                    case DayOfWeek.Sunday:
                        firstFriday = fromDate.AddDays(5);
                        break;
                    case DayOfWeek.Monday:
                        firstFriday = fromDate.AddDays(4);
                        break;
                    case DayOfWeek.Tuesday:
                        firstFriday = fromDate.AddDays(3);
                        break;
                    case DayOfWeek.Wednesday:
                        firstFriday = fromDate.AddDays(2);
                        break;
                    case DayOfWeek.Thursday:
                        firstFriday = fromDate.AddDays(1);
                        break;
                    case DayOfWeek.Friday:
                        break;
                    case DayOfWeek.Saturday:
                        firstFriday = fromDate.AddDays(6);
                        break;
                }
                var fridayDates = new List<DateTime>();
                for (DateTime date = firstFriday; date <= toDate; date = date.AddDays(7))
                {
                    fridayDates.Add(date);
                }
                var flights = new List<Flight>();


                var tasks = fridayDates.Select(f =>
                {
                    Func<IEnumerable<Flight>> func = () => GetRyanAirFlights(schedule.Origin, schedule.Destination, f, 1, f.AddDays(2), 1);
                    return new Task<IEnumerable<Flight>>(func);
                }).ToList();
                if (asParallel)
                {
                    tasks.ForEach(t => t.Start());
                    Task.WaitAll(tasks.ToArray());
                }
                else
                {
                    tasks.ForEach(t => t.RunSynchronously());
                }
                var allFlights = new List<Flight>();
                tasks.ForEach(t =>
                {
                    if (t.Result == null)
                    {
                        return;
                    }
                    allFlights.AddRange(t.Result);
                });
                if (allFlights.Count > 0)
                {
                    allFlights = allFlights.OrderBy(f => f.Friday).ToList();
                    var json = Newtonsoft.Json.JsonConvert.SerializeObject(allFlights, Newtonsoft.Json.Formatting.Indented);
                    File.WriteAllText(filePath, json);
                }
                else
                {
                    logger.Debug($"No valid flights found.");
                }
            }
            catch (Exception ex)
            {
                logger.Error(ex);
            }
            finally
            {
                sw.Stop();
                logger.Info($"Finished in {sw.ElapsedMilliseconds}ms");
            }

        }
    }
}
