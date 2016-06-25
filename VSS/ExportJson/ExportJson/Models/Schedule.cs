using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace ExportJson.Models
{
    class Schedule
    {
        public string Origin { get; set; }
        public string Destination { get; set; }
        public DateTime FirstFlightDate { get; set; }
        public DateTime LastFlightDate { get; set; }
    }
}
