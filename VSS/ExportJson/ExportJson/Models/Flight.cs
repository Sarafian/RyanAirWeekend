using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace ExportJson.Models
{
    class Flight
    {
        public string Origin { get; set; }
        public string Destination { get; set; }
        public DateTime Friday { get; set; }
        public DateTime OutboundFrom { get; set; }
        public DateTime OutboundTo { get; set; }
        public DateTime InboundFrom { get; set; }
        public DateTime InboundTo { get; set; }
        public float RegularFare { get; set; }
    }
}
