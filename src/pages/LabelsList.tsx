import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useToast } from '../context/ToastContext';
import { 
  Search, 
  Filter, 
  Printer, 
  Trash2, 
  Edit3, 
  Copy, 
  XOctagon, 
  CheckSquare, 
  Square, 
  Download, 
  Info
} from 'lucide-react';

export const LabelsList: React.FC = () => {
  const navigate = useNavigate();
  const { hasPermission, user } = useAuth();
  const { showToast } = useToast();

  const [loading, setLoading] = useState(true);
  const [labels, setLabels] = useState<any[]>([]);
  const [governorates, setGovernorates] = useState<any[]>([]);
  
  // Selection
  const [selectedIds, setSelectedIds] = useState<string[]>([]);

  // Search & Filters state
  const [searchQuery, setSearchQuery] = useState('');
  const [debouncedSearchQuery, setDebouncedSearchQuery] = useState('');

  useEffect(() => {
    const handler = setTimeout(() => {
      setDebouncedSearchQuery(searchQuery);
    }, 300);

    return () => {
      clearTimeout(handler);
    };
  }, [searchQuery]);
  const [filterGov, setFilterGov] = useState('');
  const [filterStatus, setFilterStatus] = useState('');
  const [filterPrinted, setFilterPrinted] = useState('');
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');
  const [minCod, setMinCod] = useState<number | ''>('');
  const [maxCod, setMaxCod] = useState<number | ''>('');

  // Modals state
  const [cancelModalOpen, setCancelModalOpen] = useState(false);
  const [cancelReason, setCancelReason] = useState('');
  const [targetCancelIds, setTargetCancelIds] = useState<string[]>([]);

  const [deleteModalOpen, setDeleteModalOpen] = useState(false);
  const [targetDeleteId, setTargetDeleteId] = useState<string | null>(null);

  const fetchGovernorates = async () => {
    const { data } = await supabase.from('governorate_shipping_fees').select('*').order('governorate');
    if (data) setGovernorates(data);
  };

  const fetchLabels = async () => {
    try {
      setLoading(true);
      
      // Let's build a query with filters
      const query = supabase.from('labels').select('*');

      // 1. Text Search (Local or DB based)
      if (searchQuery.trim()) {
        // Since supabase-js doesn't easily chain nested OR on different tables, we query all or filter on client,
        // or apply filter chains. To make it extremely robust and compatible with mock & live, we can fetch the query
        // and do filter matching on client or simple queries.
        // Let's query and filter on client to guarantee it runs flawlessly on both Supabase and Mock client!
      }

      const { data, error } = await query.order('created_at', { ascending: false });

      if (error) {
        showToast('خطأ في تحميل البوليصات.', 'error');
        console.error(error);
        return;
      }

      if (data) {
        // Client-side filtering to align both mock (localstorage) and real database
        let filtered = [...data];

        // Search Query
        if (debouncedSearchQuery.trim()) {
          const q = debouncedSearchQuery.toLowerCase();
          filtered = filtered.filter(item => 
            item.customer_name.toLowerCase().includes(q) ||
            item.primary_phone.includes(q) ||
            (item.secondary_phone && item.secondary_phone.includes(q)) ||
            item.tracking_number.toLowerCase().includes(q)
          );
        }

        // Governorate
        if (filterGov) {
          filtered = filtered.filter(item => item.governorate === filterGov);
        }

        // Status
        if (filterStatus) {
          filtered = filtered.filter(item => item.status === filterStatus);
        }

        // Printed Status
        if (filterPrinted) {
          const isPrinted = filterPrinted === 'true';
          filtered = filtered.filter(item => item.is_printed === isPrinted);
        }

        // Date range
        if (startDate) {
          filtered = filtered.filter(item => new Date(item.created_at) >= new Date(startDate + 'T00:00:00'));
        }
        if (endDate) {
          filtered = filtered.filter(item => new Date(item.created_at) <= new Date(endDate + 'T23:59:59'));
        }

        // COD Range
        if (minCod !== '') {
          filtered = filtered.filter(item => Number(item.cod_amount) >= Number(minCod));
        }
        if (maxCod !== '') {
          filtered = filtered.filter(item => Number(item.cod_amount) <= Number(maxCod));
        }

        setLabels(filtered);
      }
    } catch (e) {
      console.error(e);
      showToast('حدث خطأ أثناء الاتصال.', 'error');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchGovernorates();
  }, []);

  useEffect(() => {
    fetchLabels();
    setSelectedIds([]); // Clear selection when filter changes
  }, [debouncedSearchQuery, filterGov, filterStatus, filterPrinted, startDate, endDate, minCod, maxCod]);

  // Toggle selection
  const handleSelectRow = (id: string) => {
    setSelectedIds(prev => 
      prev.includes(id) ? prev.filter(x => x !== id) : [...prev, id]
    );
  };

  const handleSelectAll = () => {
    if (selectedIds.length === labels.length) {
      setSelectedIds([]);
    } else {
      setSelectedIds(labels.map(l => l.id));
    }
  };

  // Actions
  const handleDuplicate = async (label: any) => {
    try {
      setLoading(true);
      // Generate new tracking number
      const prefix = label.tracking_number.substring(0, 3);
      const now = new Date();
      const datePart = `${now.getFullYear()}${String(now.getMonth() + 1).padStart(2, '0')}${String(now.getDate()).padStart(2, '0')}`;
      const randomPart = String(Math.floor(10000 + Math.random() * 90000));
      const trackingNumber = `${prefix}${datePart}${randomPart}`;

      const duplicatedData = {
        tracking_number: trackingNumber,
        customer_name: label.customer_name + ' (مكرر)',
        primary_phone: label.primary_phone,
        secondary_phone: label.secondary_phone,
        governorate: label.governorate,
        city: label.city,
        address: label.address,
        landmark: label.landmark,
        product_name: label.product_name,
        contents: label.contents,
        pieces: label.pieces,
        weight: label.weight,
        cod_amount: label.cod_amount,
        shipping_fee: label.shipping_fee,
        payment_method: label.payment_method,
        instructions: label.instructions,
        internal_notes: label.internal_notes,
        shipper_id: label.shipper_id,
        store_name: label.store_name,
        product_type: label.product_type,
        status: 'Ready',
        is_printed: false,
        ...(user?.id ? { created_by: user.id } : {})
      };

      const { error } = await supabase.from('labels').insert(duplicatedData);
      if (error) throw error;

      showToast('تم تكرار البوليصة بنجاح كشحنة جاهزة جديدة.', 'success');
      fetchLabels();
    } catch (e: any) {
      console.error(e);
      showToast(e.message || 'خطأ أثناء التكرار.', 'error');
    } finally {
      setLoading(false);
    }
  };

  const handleMarkPrinted = async (ids: string[]) => {
    try {
      setLoading(true);
      const { error } = await supabase
        .from('labels')
        .update({
          is_printed: true,
          status: 'Printed',
          printed_at: new Date().toISOString()
        })
        .in('id', ids);

      if (error) throw error;
      showToast(`تم تحديد عدد ${ids.length} بوليصة كـ "تمت الطباعة".`, 'success');
      fetchLabels();
      setSelectedIds([]);
    } catch (e: any) {
      console.error(e);
      showToast(e.message || 'خطأ في التحديث.', 'error');
    } finally {
      setLoading(false);
    }
  };

  const openCancelModal = (ids: string[]) => {
    setTargetCancelIds(ids);
    setCancelReason('');
    setCancelModalOpen(true);
  };

  const submitCancel = async () => {
    if (!cancelReason.trim()) {
      showToast('يرجى كتابة سبب الإلغاء.', 'warning');
      return;
    }

    try {
      setLoading(true);
      const { error } = await supabase
        .from('labels')
        .update({
          status: 'Cancelled',
          cancelled_at: new Date().toISOString(),
          cancellation_reason: cancelReason.trim()
        })
        .in('id', targetCancelIds);

      if (error) throw error;
      showToast(`تم إلغاء عدد ${targetCancelIds.length} بوليصة بنجاح.`, 'success');
      setCancelModalOpen(false);
      fetchLabels();
      setSelectedIds([]);
    } catch (e: any) {
      console.error(e);
      showToast(e.message || 'حدث خطأ أثناء الإلغاء.', 'error');
    } finally {
      setLoading(false);
    }
  };

  const openDeleteModal = (id: string) => {
    setTargetDeleteId(id);
    setDeleteModalOpen(true);
  };

  const submitDelete = async () => {
    if (!targetDeleteId) return;

    try {
      setLoading(true);
      const { error } = await supabase
        .from('labels')
        .delete()
        .eq('id', targetDeleteId);

      if (error) throw error;
      showToast('تم حذف البوليصة نهائياً بنجاح.', 'success');
      setDeleteModalOpen(false);
      fetchLabels();
    } catch (e: any) {
      console.error(e);
      showToast(e.message || 'خطأ في الحذف. فقط المدير (Admin) يمتلك صلاحية الحذف.', 'error');
    } finally {
      setLoading(false);
    }
  };

  const handleBatchPrint = () => {
    if (selectedIds.length === 0) {
      showToast('يرجى تحديد بوليصات للطباعة أولاً.', 'warning');
      return;
    }
    navigate('/labels/batch', { state: { selectedIds } });
  };

  const handleExportCSV = (idsToExport: string[] = []) => {
    const list = idsToExport.length > 0 
      ? labels.filter(l => idsToExport.includes(l.id))
      : labels;

    if (list.length === 0) {
      showToast('لا توجد بيانات لتصديرها.', 'warning');
      return;
    }

    const headers = [
      'رقم البوليصة', 'اسم العميل', 'الهاتف الأساسي', 'الهاتف الإضافي',
      'المحافظة', 'المدينة/المركز', 'العنوان', 'محتويات الشحنة',
      'القطع', 'الوزن', 'مبلغ COD', 'مصاريف الشحن', 'الحالة', 'مطبوعة', 'تاريخ الإنشاء'
    ];

    const csvRows = [headers.join(',')];

    list.forEach(lbl => {
      const row = [
        lbl.tracking_number,
        `"${lbl.customer_name.replace(/"/g, '""')}"`,
        lbl.primary_phone,
        lbl.secondary_phone || '',
        lbl.governorate,
        lbl.city,
        `"${(lbl.address || '').replace(/"/g, '""')}"`,
        `"${(lbl.contents || '').replace(/"/g, '""')}"`,
        lbl.pieces,
        lbl.weight,
        lbl.cod_amount,
        lbl.shipping_fee,
        lbl.status,
        lbl.is_printed ? 'نعم' : 'لا',
        lbl.created_at.split('T')[0]
      ];
      csvRows.push(row.join(','));
    });

    const csvContent = '\uFEFF' + csvRows.join('\n');
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.setAttribute('href', url);
    link.setAttribute('download', `بوليصات_شحن_محددة_${new Date().toISOString().split('T')[0]}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    showToast('تم تصدير ملف CSV للبوليصات بنجاح.', 'success');
  };

  return (
    <div className="p-6 space-y-6">
      
      {/* Title */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 bg-white p-5 rounded-2xl border border-slate-100 shadow-sm">
        <div>
          <h1 className="text-xl font-bold text-slate-800">إدارة بوليصات الشحن</h1>
          <p className="text-xs text-slate-400 font-semibold mt-0.5">ابحث، قم بالتصفية، اطبع بوليصات الشحن جماعياً، أو تحكم بحالات الشحنات.</p>
        </div>
        
        {/* Create label direct link */}
        <button 
          onClick={() => navigate('/labels/new')}
          className="flex items-center gap-2 px-5 py-2.5 bg-falcon-navy hover:bg-falcon-blue text-white rounded-xl font-bold text-xs shadow-md transition-colors cursor-pointer"
        >
          <span>إنشاء بوليصة جديدة</span>
        </button>
      </div>

      {/* Filters Accordion */}
      <div className="bg-white rounded-2xl border border-slate-100 shadow-sm p-5 space-y-4">
        <div className="flex items-center gap-2 pb-3 border-b border-slate-100 text-slate-800">
          <Filter size={16} />
          <h2 className="text-sm font-extrabold">خيارات البحث والتصفية المتقدمة</h2>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 gap-4">
          
          {/* Text Search */}
          <div className="relative">
            <label className="block text-[10px] font-bold text-slate-400 mb-1">بحث نصي (اسم العميل / تليفون / رقم البوليصة)</label>
            <div className="relative">
              <input
                type="text"
                placeholder="ابحث هنا..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="w-full pl-3 pr-9 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:border-falcon-navy focus:bg-white font-semibold"
              />
              <Search className="absolute top-1/2 right-3 -translate-y-1/2 text-slate-400" size={14} />
            </div>
          </div>

          {/* Governorate */}
          <div>
            <label className="block text-[10px] font-bold text-slate-400 mb-1">المحافظة</label>
            <select
              value={filterGov}
              onChange={(e) => setFilterGov(e.target.value)}
              className="w-full px-3 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:border-falcon-navy font-bold"
            >
              <option value="">كل المحافظات</option>
              {governorates.map((g) => (
                <option key={g.id} value={g.governorate}>{g.governorate}</option>
              ))}
            </select>
          </div>

          {/* Status */}
          <div>
            <label className="block text-[10px] font-bold text-slate-400 mb-1">حالة البوليصة</label>
            <select
              value={filterStatus}
              onChange={(e) => setFilterStatus(e.target.value)}
              className="w-full px-3 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:border-falcon-navy font-bold"
            >
              <option value="">كل الحالات</option>
              <option value="Ready">جاهز للشحن (Ready)</option>
              <option value="Draft">مسودة (Draft)</option>
              <option value="Printed">تمت الطباعة (Printed)</option>
              <option value="Cancelled">ملغي (Cancelled)</option>
            </select>
          </div>

          {/* Printed Status */}
          <div>
            <label className="block text-[10px] font-bold text-slate-400 mb-1">حالة الطباعة ورقياً</label>
            <select
              value={filterPrinted}
              onChange={(e) => setFilterPrinted(e.target.value)}
              className="w-full px-3 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:border-falcon-navy font-bold"
            >
              <option value="">الكل</option>
              <option value="true">تم طباعتها</option>
              <option value="false">لم تطبع بعد</option>
            </select>
          </div>

          {/* Start Date */}
          <div>
            <label className="block text-[10px] font-bold text-slate-400 mb-1">من تاريخ الإنشاء</label>
            <input
              type="date"
              value={startDate}
              onChange={(e) => setStartDate(e.target.value)}
              className="w-full px-3 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:border-falcon-navy font-semibold"
            />
          </div>

          {/* End Date */}
          <div>
            <label className="block text-[10px] font-bold text-slate-400 mb-1">إلى تاريخ الإنشاء</label>
            <input
              type="date"
              value={endDate}
              onChange={(e) => setEndDate(e.target.value)}
              className="w-full px-3 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:border-falcon-navy font-semibold"
            />
          </div>

          {/* Min COD */}
          <div>
            <label className="block text-[10px] font-bold text-slate-400 mb-1">مبلغ COD الأدنى</label>
            <input
              type="number"
              placeholder="ج.م"
              value={minCod}
              onChange={(e) => setMinCod(e.target.value === '' ? '' : Number(e.target.value))}
              className="w-full px-3 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:border-falcon-navy font-semibold"
            />
          </div>

          {/* Max COD */}
          <div>
            <label className="block text-[10px] font-bold text-slate-400 mb-1">مبلغ COD الأقصى</label>
            <input
              type="number"
              placeholder="ج.م"
              value={maxCod}
              onChange={(e) => setMaxCod(e.target.value === '' ? '' : Number(e.target.value))}
              className="w-full px-3 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:border-falcon-navy font-semibold"
            />
          </div>

        </div>
      </div>

      {/* Bulk Actions Dock (Visible when rows are selected) */}
      {selectedIds.length > 0 && (
        <div className="flex flex-wrap items-center justify-between gap-3 bg-falcon-navy text-white px-6 py-4 rounded-xl shadow-lg border border-slate-800 animate-slide-up">
          <div className="flex items-center gap-2.5">
            <span className="text-xs font-black bg-falcon-orange text-white px-2.5 py-1 rounded-md">
              {selectedIds.length} محددة
            </span>
            <span className="text-xs font-semibold text-slate-300">قم بتطبيق الإجراءات الجماعية:</span>
          </div>

          <div className="flex flex-wrap items-center gap-2">
            <button
              onClick={handleBatchPrint}
              className="flex items-center gap-1.5 px-3 py-2 bg-falcon-blue hover:bg-falcon-blue/80 rounded-lg text-[11px] font-bold transition-all border border-slate-700 cursor-pointer"
            >
              <Printer size={14} />
              <span>طباعة بوليصات (A4)</span>
            </button>

            <button
              onClick={() => handleMarkPrinted(selectedIds)}
              className="flex items-center gap-1.5 px-3 py-2 bg-emerald-600 hover:bg-emerald-700 rounded-lg text-[11px] font-bold transition-all cursor-pointer"
            >
              <span>تعليم كـ "تمت الطباعة"</span>
            </button>

            <button
              onClick={() => openCancelModal(selectedIds)}
              className="flex items-center gap-1.5 px-3 py-2 bg-red-600 hover:bg-red-700 rounded-lg text-[11px] font-bold transition-all cursor-pointer"
            >
              <XOctagon size={14} />
              <span>إلغاء الشحنات</span>
            </button>

            <button
              onClick={() => handleExportCSV(selectedIds)}
              className="flex items-center gap-1.5 px-3 py-2 bg-slate-800 hover:bg-slate-700 rounded-lg text-[11px] font-bold transition-all border border-slate-700 cursor-pointer"
            >
              <Download size={14} />
              <span>تصدير CSV للمحدد</span>
            </button>

            <button
              onClick={() => setSelectedIds([])}
              className="text-[11px] font-bold text-slate-400 hover:text-white px-2 cursor-pointer"
            >
              إلغاء التحديد
            </button>
          </div>
        </div>
      )}

      {/* Table Section */}
      <div className="bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden">
        {loading ? (
          <div className="p-12 space-y-4">
            {[...Array(6)].map((_, i) => (
              <div key={i} className="h-12 bg-slate-50 rounded-xl animate-pulse"></div>
            ))}
          </div>
        ) : labels.length === 0 ? (
          <div className="p-16 text-center text-slate-400">
            <Info className="mx-auto text-slate-300 mb-3" size={44} />
            <p className="text-sm font-semibold">لم يتم العثور على بوليصات شحن تطابق معايير التصفية الحالية.</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-right border-collapse">
              <thead>
                <tr className="bg-slate-50/70 border-b border-slate-100 text-[10px] font-black text-slate-400 uppercase">
                  <th className="px-5 py-4 w-12 text-center">
                    <button onClick={handleSelectAll} className="p-1 rounded hover:bg-slate-100 text-slate-500 cursor-pointer">
                      {selectedIds.length === labels.length ? <CheckSquare size={16} className="text-falcon-navy" /> : <Square size={16} />}
                    </button>
                  </th>
                  <th className="px-5 py-4">رقم البوليصة</th>
                  <th className="px-5 py-4">العميل</th>
                  <th className="px-5 py-4">الموبايل</th>
                  <th className="px-5 py-4">المحافظة</th>
                  <th className="px-5 py-4">المنطقة</th>
                  <th className="px-5 py-4">قيمة COD</th>
                  <th className="px-5 py-4">مبلغ الشحن</th>
                  <th className="px-5 py-4">طباعة ورقياً</th>
                  <th className="px-5 py-4">الحالة</th>
                  <th className="px-5 py-4">تاريخ الإنشاء</th>
                  <th className="px-5 py-4 text-center">خيارات</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100 text-xs font-semibold text-slate-600">
                {labels.map((lbl) => {
                  const isSelected = selectedIds.includes(lbl.id);
                  
                  let statusBg = 'bg-slate-100 text-slate-600 border-slate-200';
                  if (lbl.status === 'Draft') statusBg = 'bg-amber-50 text-amber-700 border-amber-100';
                  else if (lbl.status === 'Ready') statusBg = 'bg-blue-50 text-blue-700 border-blue-100';
                  else if (lbl.status === 'Printed') statusBg = 'bg-emerald-50 text-emerald-700 border-emerald-100';
                  else if (lbl.status === 'Cancelled') statusBg = 'bg-red-50 text-red-700 border-red-100';

                  return (
                    <tr 
                      key={lbl.id} 
                      className={`hover:bg-slate-50/50 transition-colors ${isSelected ? 'bg-indigo-50/20' : ''}`}
                    >
                      {/* Checkbox select */}
                      <td className="px-5 py-4 text-center">
                        <button onClick={() => handleSelectRow(lbl.id)} className="p-1 rounded hover:bg-slate-100 text-slate-500 cursor-pointer">
                          {isSelected ? <CheckSquare size={16} className="text-falcon-navy" /> : <Square size={16} />}
                        </button>
                      </td>

                      {/* Tracking number */}
                      <td className="px-5 py-4 font-mono font-bold text-slate-700 select-all">{lbl.tracking_number}</td>
                      
                      {/* Customer Name */}
                      <td className="px-5 py-4 font-bold text-slate-800">{lbl.customer_name}</td>
                      
                      {/* Phone */}
                      <td className="px-5 py-4 font-mono font-bold text-slate-700 select-all">{lbl.primary_phone}</td>
                      
                      {/* Governorate */}
                      <td className="px-5 py-4 font-bold text-slate-800">{lbl.governorate}</td>
                      
                      {/* City */}
                      <td className="px-5 py-4 text-slate-400">{lbl.city}</td>
                      
                      {/* COD amount */}
                      <td className="px-5 py-4 font-bold text-slate-700">{lbl.cod_amount} ج.م</td>
                      
                      {/* Shipping Fee */}
                      <td className="px-5 py-4 text-slate-400">{lbl.shipping_fee} ج.م</td>

                      {/* Printed status */}
                      <td className="px-5 py-4">
                        {lbl.is_printed ? (
                          <span className="inline-flex px-2 py-0.5 rounded text-[10px] font-bold bg-green-50 text-green-700 border border-green-200">
                            نعم (مطبوع)
                          </span>
                        ) : (
                          <span className="inline-flex px-2 py-0.5 rounded text-[10px] font-bold bg-slate-100 text-slate-400 border border-slate-200">
                            لا (غير مطبوع)
                          </span>
                        )}
                      </td>

                      {/* Status */}
                      <td className="px-5 py-4">
                        <span className={`inline-flex px-2 py-0.5 rounded border text-[10px] font-bold ${statusBg}`}>
                          {lbl.status === 'Draft' && 'مسودة'}
                          {lbl.status === 'Ready' && 'جاهز للشحن'}
                          {lbl.status === 'Printed' && 'تمت الطباعة'}
                          {lbl.status === 'Cancelled' && 'ملغي'}
                        </span>
                      </td>

                      {/* Created date */}
                      <td className="px-5 py-4 text-slate-400">{lbl.created_at.split('T')[0]}</td>

                      {/* Actions */}
                      <td className="px-5 py-4">
                        <div className="flex items-center justify-center gap-2">
                          <button
                            onClick={() => navigate('/labels/batch', { state: { selectedIds: [lbl.id] } })}
                            title="معاينة وطباعة"
                            className="p-1.5 hover:bg-slate-100 text-slate-500 hover:text-falcon-navy rounded-lg transition-colors cursor-pointer"
                          >
                            <Printer size={14} />
                          </button>
                          <button
                            onClick={() => navigate(`/labels/edit/${lbl.id}`)}
                            title="تعديل"
                            className="p-1.5 hover:bg-slate-100 text-slate-500 hover:text-indigo-600 rounded-lg transition-colors cursor-pointer"
                          >
                            <Edit3 size={14} />
                          </button>
                          <button
                            onClick={() => handleDuplicate(lbl)}
                            title="تكرار الشحنة"
                            className="p-1.5 hover:bg-slate-100 text-slate-500 hover:text-emerald-600 rounded-lg transition-colors cursor-pointer"
                          >
                            <Copy size={14} />
                          </button>
                          {lbl.status !== 'Cancelled' && (
                            <button
                              onClick={() => openCancelModal([lbl.id])}
                              title="إلغاء الشحنة"
                              className="p-1.5 hover:bg-red-50 text-slate-500 hover:text-red-600 rounded-lg transition-colors cursor-pointer"
                            >
                              <XOctagon size={14} />
                            </button>
                          )}
                          {hasPermission('shipping_labels.delete') && (
                            <button
                              onClick={() => openDeleteModal(lbl.id)}
                              title="حذف نهائي"
                              className="p-1.5 hover:bg-red-50 text-red-500 hover:text-red-700 rounded-lg transition-colors cursor-pointer"
                            >
                              <Trash2 size={14} />
                            </button>
                          )}
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Cancellation Reason Dialog */}
      {cancelModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm no-print p-4">
          <div className="bg-white rounded-2xl border border-slate-100 p-6 max-w-md w-full shadow-2xl animate-scale-up">
            <h3 className="text-base font-bold text-slate-800 mb-3">تأكيد إلغاء الشحنة</h3>
            <p className="text-xs text-slate-400 font-semibold mb-4 leading-relaxed">
              يرجى إدخال سبب الإلغاء لتوثيقه في سجل النظام. لا يمكن للمندوبين شحن بوليصة ملغية.
            </p>
            
            <textarea
              placeholder="اكتب سبب إلغاء الشحنة بالتفصيل..."
              value={cancelReason}
              onChange={(e) => setCancelReason(e.target.value)}
              rows={3}
              className="w-full px-3 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:border-falcon-navy focus:bg-white font-semibold mb-4"
              required
            />

            <div className="flex items-center justify-end gap-2">
              <button
                type="button"
                onClick={() => setCancelModalOpen(false)}
                className="px-4 py-2 border border-slate-200 hover:bg-slate-50 text-slate-700 rounded-lg font-bold text-xs cursor-pointer"
              >
                تراجع
              </button>
              <button
                type="button"
                onClick={submitCancel}
                className="px-5 py-2 bg-red-600 hover:bg-red-700 text-white rounded-lg font-bold text-xs shadow-md cursor-pointer"
              >
                تأكيد الإلغاء
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Delete Confirmation Dialog */}
      {deleteModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm no-print p-4">
          <div className="bg-white rounded-2xl border border-slate-100 p-6 max-w-md w-full shadow-2xl animate-scale-up">
            <h3 className="text-base font-bold text-red-600 mb-2">تأكيد الحذف النهائي</h3>
            <p className="text-xs text-slate-400 font-semibold mb-5 leading-relaxed">
              تحذير: هل أنت متأكد من رغبتك في حذف هذه البوليصة نهائياً من قواعد البيانات؟ لا يمكن التراجع عن هذا الإجراء وسيتم شطب السجل بالكامل.
            </p>

            <div className="flex items-center justify-end gap-2">
              <button
                type="button"
                onClick={() => setDeleteModalOpen(false)}
                className="px-4 py-2 border border-slate-200 hover:bg-slate-50 text-slate-700 rounded-lg font-bold text-xs cursor-pointer"
              >
                تراجع
              </button>
              <button
                type="button"
                onClick={submitDelete}
                className="px-5 py-2 bg-red-600 hover:bg-red-700 text-white rounded-lg font-bold text-xs shadow-md cursor-pointer"
              >
                حذف نهائي
              </button>
            </div>
          </div>
        </div>
      )}

    </div>
  );
};
