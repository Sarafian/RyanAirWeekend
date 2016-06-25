using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace ExportJson.Models.FromJson
{
    public class Fare
    {
        public string type { get; set; }
        public float amount { get; set; }
        public int count { get; set; }
        public bool hasDiscount { get; set; }
        public float publishedFare { get; set; }
    }

    public class RegularFare
    {
        public string fareKey { get; set; }
        public string fareClass { get; set; }
        public List<Fare> fares { get; set; }
    }

    public class Fare2
    {
        public string type { get; set; }
        public float amount { get; set; }
        public int count { get; set; }
        public bool hasDiscount { get; set; }
        public float publishedFare { get; set; }
    }

    public class BusinessFare
    {
        public string fareKey { get; set; }
        public string fareClass { get; set; }
        public List<Fare2> fares { get; set; }
    }

    public class Fare3
    {
        public string type { get; set; }
        public float amount { get; set; }
        public int count { get; set; }
        public bool hasDiscount { get; set; }
        public float publishedFare { get; set; }
    }

    public class LeisureFare
    {
        public string fareKey { get; set; }
        public string fareClass { get; set; }
        public List<Fare3> fares { get; set; }
    }

    public class Flight
    {
        public string flightNumber { get; set; }
        public List<string> time { get; set; }
        public List<string> timeUTC { get; set; }
        public string duration { get; set; }
        public int faresLeft { get; set; }
        public string flightKey { get; set; }
        public int infantsLeft { get; set; }
        public RegularFare regularFare { get; set; }
        public BusinessFare businessFare { get; set; }
        public LeisureFare leisureFare { get; set; }
    }

    public class Date
    {
        public string dateOut { get; set; }
        public List<Flight> flights { get; set; }
    }

    public class Trip
    {
        public string origin { get; set; }
        public string destination { get; set; }
        public List<Date> dates { get; set; }
    }

    public class RootObject
    {
        public string currency { get; set; }
        public int currPrecision { get; set; }
        public List<Trip> trips { get; set; }
        public string serverTimeUTC { get; set; }
    }
}
