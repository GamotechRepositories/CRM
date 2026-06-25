import React from 'react'

const ReportsView = () => {
  return (
    <div className='p-8'>
      <div className='mb-8 flex justify-between items-center'>
        <div>
          <h1 className='text-3xl font-bold text-gray-900'>Reports</h1>
          <p className='text-gray-600 mt-2'>Analyze performance metrics and insights.</p>
        </div>
        <button className='bg-red-600 hover:bg-red-700 text-white px-6 py-2 rounded-lg font-semibold transition-colors'>
          + Generate Report
        </button>
      </div>

      <div className='grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8'>
        <div className='bg-white rounded-lg shadow-md p-6'>
          <h2 className='text-lg font-bold text-gray-900 mb-4'>Revenue by Client</h2>
          <div className='space-y-4'>
            {[
              { client: 'Tech Corp Inc', amount: '$150K', percentage: 30 },
              { client: 'E-Commerce Hub', amount: '$120K', percentage: 24 },
              { client: 'Digital Solutions', amount: '$85K', percentage: 17 },
              { client: 'Marketing Plus', amount: '$60K', percentage: 12 },
              { client: 'Others', amount: '$85K', percentage: 17 },
            ].map((item, idx) => (
              <div key={idx}>
                <div className='flex justify-between mb-1'>
                  <span className='text-sm font-medium text-gray-700'>{item.client}</span>
                  <span className='text-sm font-bold text-gray-900'>{item.amount}</span>
                </div>
                <div className='w-full bg-gray-200 rounded-full h-2'>
                  <div
                    className='bg-gradient-to-r from-red-500 to-pink-500 h-2 rounded-full'
                    style={{ width: `${item.percentage}%` }}
                  ></div>
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className='bg-white rounded-lg shadow-md p-6'>
          <h2 className='text-lg font-bold text-gray-900 mb-4'>Campaign Performance</h2>
          <div className='space-y-4'>
            {[
              { campaign: 'SEO Optimization', roi: '+245%', clicks: '12.5K' },
              { campaign: 'Social Media', roi: '+185%', clicks: '8.3K' },
              { campaign: 'Email Marketing', roi: '+320%', clicks: '5.2K' },
              { campaign: 'Content Marketing', roi: '+142%', clicks: '3.8K' },
              { campaign: 'PPC Ads', roi: '+198%', clicks: '15.6K' },
            ].map((item, idx) => (
              <div key={idx} className='flex items-center justify-between p-3 bg-gray-50 rounded-lg border border-gray-200'>
                <div>
                  <p className='text-sm font-medium text-gray-900'>{item.campaign}</p>
                  <p className='text-xs text-gray-600'>{item.clicks} clicks</p>
                </div>
                <span className='text-lg font-bold text-green-600'>{item.roi}</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      <div className='grid grid-cols-1 gap-6'>
        <div className='bg-white rounded-lg shadow-md p-6'>
          <h2 className='text-lg font-bold text-gray-900 mb-4'>Monthly Performance Trend</h2>
          <div className='h-64 flex items-end justify-between gap-2'>
            {[
              { month: 'Jan', revenue: 45, leads: 38, conversion: 22 },
              { month: 'Feb', revenue: 52, leads: 45, conversion: 26 },
              { month: 'Mar', revenue: 48, leads: 42, conversion: 24 },
              { month: 'Apr', revenue: 65, leads: 58, conversion: 32 },
              { month: 'May', revenue: 55, leads: 52, conversion: 28 },
              { month: 'Jun', revenue: 70, leads: 68, conversion: 35 },
              { month: 'Jul', revenue: 78, leads: 75, conversion: 42 },
              { month: 'Aug', revenue: 85, leads: 82, conversion: 45 },
              { month: 'Sep', revenue: 80, leads: 78, conversion: 43 },
              { month: 'Oct', revenue: 90, leads: 88, conversion: 48 },
              { month: 'Nov', revenue: 95, leads: 92, conversion: 50 },
              { month: 'Dec', revenue: 88, leads: 85, conversion: 46 },
            ].map((item, idx) => (
              <div key={idx} className='flex-1 flex flex-col items-center'>
                <div className='w-full flex items-end justify-between gap-1' style={{ height: '240px' }}>
                  <div
                    className='flex-1 bg-blue-500 rounded-t opacity-70'
                    style={{ height: `${item.revenue}%` }}
                    title={`${item.month} Revenue`}
                  ></div>
                  <div
                    className='flex-1 bg-green-500 rounded-t opacity-70'
                    style={{ height: `${item.leads}%` }}
                    title={`${item.month} Leads`}
                  ></div>
                  <div
                    className='flex-1 bg-purple-500 rounded-t opacity-70'
                    style={{ height: `${item.conversion}%` }}
                    title={`${item.month} Conversion`}
                  ></div>
                </div>
                <span className='text-xs text-gray-600 mt-2'>{item.month}</span>
              </div>
            ))}
          </div>
          <div className='flex justify-center gap-6 mt-4'>
            <div className='flex items-center gap-2'>
              <div className='w-4 h-4 bg-blue-500 rounded'></div>
              <span className='text-xs font-medium text-gray-700'>Revenue</span>
            </div>
            <div className='flex items-center gap-2'>
              <div className='w-4 h-4 bg-green-500 rounded'></div>
              <span className='text-xs font-medium text-gray-700'>Leads</span>
            </div>
            <div className='flex items-center gap-2'>
              <div className='w-4 h-4 bg-purple-500 rounded'></div>
              <span className='text-xs font-medium text-gray-700'>Conversion</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

export default ReportsView
