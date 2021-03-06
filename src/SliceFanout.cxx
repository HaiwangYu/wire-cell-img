#include "WireCellImg/SliceFanout.h"

#include "WireCellUtil/NamedFactory.h"
#include "WireCellUtil/Exceptions.h"

#include <iostream>

WIRECELL_FACTORY(SliceFanout, WireCell::Img::SliceFanout,
                 WireCell::ISliceFanout, WireCell::IConfigurable)


using namespace WireCell;

Img::SliceFanout::SliceFanout(size_t multiplicity)
    : m_multiplicity(multiplicity)
{
}
Img::SliceFanout::~SliceFanout()
{
}

WireCell::Configuration Img::SliceFanout::default_configuration() const
{
    Configuration cfg;
    // How many output ports
    cfg["multiplicity"] = (int)m_multiplicity;
    return cfg;
}
void Img::SliceFanout::configure(const WireCell::Configuration& cfg)
{
    int m = get<int>(cfg, "multiplicity", (int)m_multiplicity);
    if (m<=0) {
        THROW(ValueError() << errmsg{"SliceFanout multiplicity must be positive"});
    }
    m_multiplicity = m;
}


std::vector<std::string> Img::SliceFanout::output_types()
{
    const std::string tname = std::string(typeid(output_type).name());
    std::vector<std::string> ret(m_multiplicity, tname);
    return ret;
}


bool Img::SliceFanout::operator()(const input_pointer& in, output_vector& outv)
{
    std::cerr << "SliceFanout: " << m_multiplicity << "x of #" << in->ident()
                  << " t=" << in->start() << " + " << in->span()
                  << " in nchan=" << in->activity().size()
                  << std::endl;
        
    outv.resize(m_multiplicity);

    for (size_t ind=0; ind<m_multiplicity; ++ind) {
        outv[ind] = in;
    }
    return true;
}
