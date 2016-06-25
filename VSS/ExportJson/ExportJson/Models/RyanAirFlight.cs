using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace ExportJson.Models
{

   

    class RyanAirFlight
    {
        public string Origin { get; set; }
        public string Destination { get; set; }
        public DateTime Date { get; set; }
        public string FlightNumber { get; set; }
        public DateTime From { get; set; }
        public DateTime To { get; set; }
        public float RegularFare { get; set; }
    }
}
