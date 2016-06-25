using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace ExportJson.Models
{
    class WeekendExcursionSettings
    {
        public int OutboundEarliestFriday { get; set; }
        public int OutboundLatestSaturday { get; set; }
        public int InboundEarliestSunday { get; set; }
        public int InboundLatestMonday { get; set; }
    }
}
