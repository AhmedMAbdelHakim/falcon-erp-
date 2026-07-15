import React, { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import { useToast } from '../context/ToastContext';
import { FileClock, AlertCircle, RefreshCcw, Search } from 'lucide-react';

export const CancelledLabels: React.FC = () => {
  const { showToast } = useToast();

  const [loading, setLoading] = useState(true);
  const [cancelledLabels, setCancelledLabels] = useState<any[]>([]);
  const [searchQuery, setSearchQuery] = useState('');

  const fetchCancelledLabels = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('labels')
        .select('*')
        .eq('status', 'Cancelled')
        .order('cancelled_at', { ascending: false });

      if (error) throw error;
      if (data) {
        setCancelledLabels(data);
      }
    } catch (e) {
      console.error(e);
      showToast('خطأ في تحميل البوليصات الملغية.', 'error');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchCancelledLabels();
  }, []);

  const handleRestore = async (id: string) => {
    try {
      setLoading(true);
      const { error } = await supabase
        .from('labels')
        .update({
          status: 'Ready',
          cancelled_at: null,
          cancellation_reason: null
        })
        .eq('id', id);

      if (error) throw error;
      showToast('تم استعادة البوليصة بنجاح وإعادة حالتها إلى "جاهز للشحن".', 'success');
      fetchCancelledLabels();
    } catch (e: any) {
      console.error(e);
      showToast(e.message || 'حدث خطأ أثناء محاولة استعادة البوليصة.', 'error');
    } finally {
      setLoading(false);
    }
  };

  const filteredLabels = cancelledLabels.filter(item => {
    if (!searchQuery.trim()) return true;
    const q = searchQuery.toLowerCase();
    return (
      item.customer_name.toLowerCase().includes(q) ||
      item.primary_phone.includes(q) ||
      item.tracking_number.toLowerCase().includes(q) ||
      (item.cancellation_reason && item.cancellation_reason.toLowerCase().includes(q))
    );
  });

  return (
    <div className="p-6 space-y-6">
      
      {/* Title */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 bg-white p-5 rounded-2xl border border-slate-100 shadow-sm">
        <div className="flex items-center gap-3">
          <div className="p-2 bg-red-50 text-red-600 rounded-xl border border-red-100">
            <FileClock size={22} />
          </div>
          <div>
            <h1 className="text-xl font-bold text-slate-800 font-sans">أرشيف البوليصات الملغية</h1>
            <p className="text-xs text-slate-400 font-semibold mt-0.5">شاهد قائمة بجميع البوليصات التي تم إلغاؤها وأسباب الإلغاء، مع خيار استعادتها.</p>
          </div>
        </div>

        {/* Search Input */}
        <div className="relative w-full md:w-80">
          <input
            type="text"
            placeholder="بحث في الملغيات..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-3 pr-9 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:border-red-500 focus:bg-white font-semibold"
          />
          <Search className="absolute top-1/2 right-3 -translate-y-1/2 text-slate-400" size={14} />
        </div>
      </div>

      {/* List Table */}
      <div className="bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden">
        {loading ? (
          <div className="p-12 space-y-4">
            {[...Array(4)].map((_, i) => (
              <div key={i} className="h-12 bg-slate-50 rounded-xl animate-pulse"></div>
            ))}
          </div>
        ) : filteredLabels.length === 0 ? (
          <div className="p-16 text-center text-slate-400">
            <AlertCircle className="mx-auto text-slate-300 mb-3" size={44} />
            <p className="text-sm font-semibold">لا توجد بوليصات ملغية حالياً.</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-right border-collapse">
              <thead>
                <tr className="bg-slate-50/70 border-b border-slate-100 text-[10px] font-black text-slate-400 uppercase">
                  <th className="px-6 py-4">رقم البوليصة</th>
                  <th className="px-6 py-4">العميل</th>
                  <th className="px-6 py-4">الموبايل</th>
                  <th className="px-6 py-4">المحافظة</th>
                  <th className="px-6 py-4">قيمة COD</th>
                  <th className="px-6 py-4">سبب الإلغاء</th>
                  <th className="px-6 py-4">تاريخ الإلغاء</th>
                  <th className="px-6 py-4 text-center">الإجراءات</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100 text-xs font-semibold text-slate-600">
                {filteredLabels.map((lbl) => (
                  <tr key={lbl.id} className="hover:bg-slate-50/50 transition-colors">
                    <td className="px-6 py-4 font-mono font-bold text-slate-700">{lbl.tracking_number}</td>
                    <td className="px-6 py-4 font-bold text-slate-800">{lbl.customer_name}</td>
                    <td className="px-6 py-4 font-mono select-all">{lbl.primary_phone}</td>
                    <td className="px-6 py-4 font-bold text-slate-800">{lbl.governorate}</td>
                    <td className="px-6 py-4 font-bold text-slate-700">{lbl.cod_amount} ج.م</td>
                    <td className="px-6 py-4 text-red-600 bg-red-50/30 max-w-xs truncate" title={lbl.cancellation_reason}>
                      {lbl.cancellation_reason}
                    </td>
                    <td className="px-6 py-4 text-slate-400">{lbl.cancelled_at ? lbl.cancelled_at.split('T')[0] : 'غير معروف'}</td>
                    <td className="px-6 py-4 text-center">
                      <button
                        onClick={() => handleRestore(lbl.id)}
                        className="inline-flex items-center gap-1 px-3 py-1.5 bg-emerald-50 border border-emerald-100 text-emerald-700 hover:bg-emerald-100 rounded-lg text-[10px] font-bold transition-all cursor-pointer"
                        title="استعادة البوليصة كـ جاهزة للشحن"
                      >
                        <RefreshCcw size={11} />
                        <span>استعادة الشحنة</span>
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

    </div>
  );
};
