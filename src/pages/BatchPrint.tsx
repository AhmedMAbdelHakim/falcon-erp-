import React, { useEffect, useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { useToast } from '../context/ToastContext';
import { WaybillLabel } from '../components/WaybillLabel';
import { ArrowRight, Printer, CheckCircle, LayoutGrid, Info } from 'lucide-react';

export const BatchPrint: React.FC = () => {
  const location = useLocation();
  const navigate = useNavigate();
  const { showToast } = useToast();

  const [loading, setLoading] = useState(true);
  const [selectedLabels, setSelectedLabels] = useState<any[]>([]);
  const [layout, setLayout] = useState<'2' | '3'>('3'); // Default print layout: 3 labels per A4

  const selectedIds = location.state?.selectedIds || [];

  useEffect(() => {
    const fetchSelectedLabels = async () => {
      if (selectedIds.length === 0) {
        showToast('لم يتم اختيار أي بوليصات للطباعة.', 'warning');
        navigate('/labels');
        return;
      }

      try {
        setLoading(true);
        const { data, error } = await supabase
          .from('labels')
          .select('*')
          .in('id', selectedIds);

        if (error) throw error;
        if (data) {
          // Sort them in the order of the selected IDs to preserve user order
          const sortedData = [...data].sort(
            (a, b) => selectedIds.indexOf(a.id) - selectedIds.indexOf(b.id)
          );
          setSelectedLabels(sortedData);
        }

        // Fetch store settings default print layout
        const { data: configData } = await supabase
          .from('shipping_settings')
          .select('*')
          .eq('key', 'store_config')
          .single();

        if (configData && configData.value) {
          const defaultLayout = (configData.value as { default_layout?: string }).default_layout;
          if (defaultLayout === '2' || defaultLayout === '3') {
            setLayout(defaultLayout);
          }
        }
      } catch (err: any) {
        console.error(err);
        showToast('خطأ أثناء تحميل البوليصات المحددة.', 'error');
      } finally {
        setLoading(false);
      }
    };

    fetchSelectedLabels();
  }, [JSON.stringify(selectedIds)]);

  // Chunk array to fit A4 layout constraints
  const chunkLabels = (arr: any[], size: number) => {
    const chunks = [];
    for (let i = 0; i < arr.length; i += size) {
      chunks.push(arr.slice(i, i + size));
    }
    return chunks;
  };

  const handlePrint = () => {
    showToast('جاري بدء الطباعة / تصدير PDF...', 'info');
    window.print();
  };

  const handleMarkAsPrinted = async () => {
    try {
      setLoading(true);
      const { error } = await supabase
        .from('labels')
        .update({
          is_printed: true,
          status: 'Printed',
          printed_at: new Date().toISOString()
        })
        .in('id', selectedIds);

      if (error) throw error;
      showToast('تم تعيين البوليصات كـ "مطبوعة ورقياً" بنجاح.', 'success');
      
      // Refresh local state status
      setSelectedLabels(prev => 
        prev.map(item => ({ ...item, is_printed: true, status: 'Printed' }))
      );
    } catch (e: any) {
      console.error(e);
      showToast(e.message || 'فشل تحديث حالة البوليصات.', 'error');
    } finally {
      setLoading(false);
    }
  };

  if (loading && selectedLabels.length === 0) {
    return (
      <div className="p-10 flex flex-col items-center justify-center min-h-[500px] no-print">
        <div className="w-12 h-12 border-4 border-falcon-navy border-t-transparent rounded-full animate-spin mb-4"></div>
        <span className="text-sm font-bold text-slate-500">جاري تجهيز البوليصات للطباعة...</span>
      </div>
    );
  }

  const itemsPerPage = layout === '3' ? 3 : 2;
  const pages = chunkLabels(selectedLabels, itemsPerPage);

  return (
    <div className="min-h-screen bg-slate-900/10 p-0 md:p-6" dir="rtl">
      
      {/* 1. Header Toolbar (Hidden on Print) */}
      <div className="max-w-4xl mx-auto mb-6 bg-white p-5 rounded-2xl border border-slate-200/60 shadow-md no-print flex flex-col md:flex-row md:items-center justify-between gap-4">
        
        {/* Title */}
        <div className="flex items-center gap-3">
          <button 
            onClick={() => navigate(-1)} 
            className="p-2 hover:bg-slate-50 rounded-xl transition-colors border border-slate-100 cursor-pointer"
          >
            <ArrowRight size={18} className="text-slate-600" />
          </button>
          <div>
            <h1 className="text-base font-black text-slate-800">معاينة طباعة البوليصات (A4)</h1>
            <p className="text-[11px] text-slate-400 font-bold mt-0.5">
              مجموع البوليصات المحددة: <span className="text-falcon-orange">{selectedLabels.length}</span> | عدد صفحات A4 المتوقعة: <span className="text-falcon-orange">{pages.length}</span>
            </p>
          </div>
        </div>

        {/* Toolbar Controls */}
        <div className="flex flex-wrap items-center gap-2">
          
          {/* Toggle Layout */}
          <div className="flex items-center border border-slate-200 rounded-xl overflow-hidden bg-slate-50 p-0.5">
            <button
              onClick={() => setLayout('3')}
              className={`px-3 py-1.5 text-[10px] font-bold rounded-lg transition-all flex items-center gap-1 cursor-pointer ${layout === '3' ? 'bg-falcon-navy text-white shadow-sm' : 'text-slate-600 hover:bg-slate-100'}`}
            >
              <LayoutGrid size={12} />
              <span>3 ملصقات/صفحة</span>
            </button>
            <button
              onClick={() => setLayout('2')}
              className={`px-3 py-1.5 text-[10px] font-bold rounded-lg transition-all flex items-center gap-1 cursor-pointer ${layout === '2' ? 'bg-falcon-navy text-white shadow-sm' : 'text-slate-600 hover:bg-slate-100'}`}
            >
              <LayoutGrid size={12} />
              <span>ملصقان/صفحة</span>
            </button>
          </div>

          {/* Mark Printed */}
          <button
            onClick={handleMarkAsPrinted}
            className="flex items-center gap-1.5 px-3 py-2 bg-emerald-50 border border-emerald-100 text-emerald-700 hover:bg-emerald-100 rounded-xl font-bold text-xs transition-all cursor-pointer"
            title="تعليم كـ مطبوع في قاعدة البيانات"
          >
            <CheckCircle size={14} />
            <span>تحديث كـ "مطبوعة"</span>
          </button>

          {/* Print Action */}
          <button
            onClick={handlePrint}
            className="flex items-center gap-1.5 px-5 py-2 bg-falcon-navy hover:bg-falcon-blue text-white rounded-xl font-extrabold text-xs shadow-md transition-all cursor-pointer"
          >
            <Printer size={14} />
            <span>بدء الطباعة / تصدير PDF</span>
          </button>

        </div>
      </div>

      {/* 2. PDF Print Guide Banner (Hidden on Print) */}
      <div className="max-w-4xl mx-auto mb-6 bg-amber-50 border border-amber-200 p-4 rounded-xl no-print flex items-start gap-3">
        <Info className="text-amber-600 mt-0.5 shrink-0" size={16} />
        <div className="text-xs text-amber-800 leading-relaxed font-semibold">
          <p className="font-extrabold text-amber-950">نصيحة هامة للحصول على بوليصات مطبوعة بدقة عالية:</p>
          <p className="mt-1">
            عند النقر على "بدء الطباعة"، سيفتح المتصفح نافذة الطباعة الافتراضية. لتصدير ملف PDF جاهز للقص، اختر الوجهة <span className="font-extrabold text-black">"حفظ كملف PDF" (Save as PDF)</span>، ثم تأكد من تعيين الخيارات التالية:
          </p>
          <ul className="list-disc pr-5 mt-1.5 space-y-0.5 text-amber-950 font-bold">
            <li>حجم الورق: <span className="underline">A4</span></li>
            <li>الهوامش: <span className="underline">بلا هوامش (None)</span> أو <span className="underline">الافتراضية (Default)</span></li>
            <li>القياس: <span className="underline">100% (Actual Size)</span> لمنع تمدد البوليصات أو تداخلها.</li>
            <li>إلغاء تحديد خيار "رؤوس وتذييلات الصفحة" (Headers and footers).</li>
          </ul>
        </div>
      </div>

      {/* 3. A4 Sheet Paper Render Engine (Visible for both Preview and Print) */}
      <div className="print-area w-full flex flex-col items-center">
        {pages.map((pageLabels, pageIdx) => {
          return (
            <div 
              key={pageIdx} 
              className="a4-preview-page a4-page"
            >
              {pageLabels.map((lbl, lblIdx) => {
                // Determine layout-specific vertical gap
                const showDivider = lblIdx < pageLabels.length - 1;
                const gapStyle: React.CSSProperties = {
                  height: layout === '3' ? '4mm' : '6mm',
                  width: '190mm',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  boxSizing: 'border-box'
                };

                return (
                  <React.Fragment key={lbl.id}>
                    
                    {/* Render single Waybill */}
                    <WaybillLabel label={lbl} layout={layout} />

                    {/* Render dash cutting line between labels */}
                    {showDivider && (
                      <div style={gapStyle} className="no-print">
                        <div className="w-full border-b border-dashed border-slate-300"></div>
                      </div>
                    )}
                    {showDivider && (
                      <div style={gapStyle} className="hidden print:flex">
                        <div className="w-full border-b-2 border-dashed border-black"></div>
                      </div>
                    )}

                  </React.Fragment>
                );
              })}
            </div>
          );
        })}
      </div>

    </div>
  );
};
