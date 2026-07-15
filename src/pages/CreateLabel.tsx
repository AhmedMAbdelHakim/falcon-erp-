import React, { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useToast } from '../context/ToastContext';
import { Save, Printer, PlusCircle, ArrowRight, Eye } from 'lucide-react';
import { WaybillLabel } from '../components/WaybillLabel';

export const CreateLabel: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const isEditMode = !!id;
  
  const navigate = useNavigate();
  const { user } = useAuth();
  const { showToast } = useToast();

  const [loading, setLoading] = useState(false);
  const [fetchingData, setFetchingData] = useState(isEditMode);
  const [governorates, setGovernorates] = useState<any[]>([]);
  const [storeConfig, setStoreConfig] = useState({
    store_name: 'Falcon store',
    shipper_id: '6525',
    default_product_type: 'COD',
    default_weight: 1.0,
    default_pieces: 1,
    barcode_prefix: 'FLC'
  });

  // Form Fields
  const [trackingNumber, setTrackingNumber] = useState('');
  const [customerName, setCustomerName] = useState('');
  const [primaryPhone, setPrimaryPhone] = useState('');
  const [secondaryPhone, setSecondaryPhone] = useState('');
  const [governorate, setGovernorate] = useState('');
  const [city, setCity] = useState('');
  const [address, setAddress] = useState('');
  const [landmark, setLandmark] = useState('');
  const [productName, setProductName] = useState('');
  const [contents, setContents] = useState('جراب هاتف فلكون');
  const [pieces, setPieces] = useState(1);
  const [weight, setWeight] = useState(1.0);
  const [codAmount, setCodAmount] = useState<number | ''>('');
  const [shippingFee, setShippingFee] = useState<number>(0);
  const [instructions, setInstructions] = useState('');
  const [internalNotes, setInternalNotes] = useState('');
  const [paymentMethod, setPaymentMethod] = useState('COD');
  const [status, setStatus] = useState('Ready');
  const [cancellationReason, setCancellationReason] = useState('');
  const [originalCancelledAt, setOriginalCancelledAt] = useState<string | null>(null);

  // Load Governorates and Store config
  useEffect(() => {
    const bootstrap = async () => {
      try {
        // Load governorates
        const { data: govData } = await supabase
          .from('governorate_shipping_fees')
          .select('*')
          .order('governorate', { ascending: true });
        
        if (govData) setGovernorates(govData);

        // Load store config
        const { data: configData } = await supabase
          .from('shipping_settings')
          .select('*')
          .eq('key', 'store_config')
          .single();

        if (configData && configData.value) {
          const config = configData.value as unknown as typeof storeConfig;
          setStoreConfig(config);
          
          if (!isEditMode) {
            setPieces(config.default_pieces || 1);
            setWeight(config.default_weight || 1.0);
          }
        }

        // If in Edit Mode, fetch the existing label
        if (isEditMode) {
          const { data: label, error } = await supabase
            .from('labels')
            .select('*')
            .eq('id', id)
            .single();

          if (error || !label) {
            showToast('لم يتم العثور على البوليصة المطلوبة.', 'error');
            navigate('/labels');
            return;
          }

          setTrackingNumber(label.tracking_number);
          setCustomerName(label.customer_name);
          setPrimaryPhone(label.primary_phone);
          setSecondaryPhone(label.secondary_phone || '');
          setGovernorate(label.governorate);
          setCity(label.city);
          setAddress(label.address);
          setLandmark(label.landmark || '');
          setProductName(label.product_name || '');
          setContents(label.contents);
          setPieces(label.pieces);
          setWeight(Number(label.weight));
          setCodAmount(Number(label.cod_amount));
          setShippingFee(Number(label.shipping_fee));
          setInstructions(label.instructions || '');
          setInternalNotes(label.internal_notes || '');
          setPaymentMethod(label.payment_method);
          setStatus(label.status);
          setCancellationReason(label.cancellation_reason || '');
          setOriginalCancelledAt(label.cancelled_at || null);
        }
      } catch (err: any) {
        console.error(err);
        showToast('حدث خطأ أثناء تحميل بيانات البوليصة.', 'error');
        navigate('/labels');
      } finally {
        setFetchingData(false);
      }
    };

    bootstrap();
  }, [id, isEditMode, navigate]);

  // Handle Governorate change to auto-update shipping fee
  const handleGovernorateChange = (selectedGov: string) => {
    setGovernorate(selectedGov);
    const govObj = governorates.find(g => g.governorate === selectedGov);
    if (govObj) {
      setShippingFee(Number(govObj.shipping_fee));
    }
  };

  // Generate Unique Tracking Number
  const generateTrackingNumber = () => {
    const prefix = storeConfig.barcode_prefix || 'FLC';
    const now = new Date();
    const year = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, '0');
    const day = String(now.getDate()).padStart(2, '0');
    const datePart = `${year}${month}${day}`;
    // 5 random digits
    const randomPart = String(Math.floor(10000 + Math.random() * 90000));
    return `${prefix}${datePart}${randomPart}`;
  };

  // Validation
  const validateForm = () => {
    if (!customerName.trim()) return 'يرجى إدخال اسم العميل.';
    if (!primaryPhone.trim()) return 'يرجى إدخال رقم الهاتف الأساسي.';
    
    // Egyptian phone validation: starts with 010, 011, 012, 015 and has 11 digits
    const egPhoneRegex = /^01[0125]\d{8}$/;
    if (!egPhoneRegex.test(primaryPhone.trim())) {
      return 'رقم الهاتف الأساسي غير صحيح. يجب أن يكون رقماً مصرياً مكوناً من 11 رقماً ويبدأ بـ 010 أو 011 أو 012 أو 015.';
    }

    if (secondaryPhone.trim() && !egPhoneRegex.test(secondaryPhone.trim())) {
      return 'رقم الهاتف الإضافي غير صحيح. يجب أن يكون رقماً مصرياً مكوناً من 11 رقماً ويبدأ بـ 010 أو 011 أو 012 أو 015.';
    }

    if (!governorate) return 'يرجى اختيار المحافظة.';
    if (!city.trim()) return 'يرجى إدخال المدينة / المركز.';
    if (!address.trim()) return 'يرجى إدخال العنوان بالتفصيل.';
    if (!contents.trim()) return 'يرجى إدخال محتويات الشحنة.';
    
    if (codAmount === '' || isNaN(Number(codAmount)) || Number(codAmount) < 0) {
      return 'يرجى إدخال مبلغ تحصيل COD صحيح (أكبر من أو يساوي 0).';
    }

    if (pieces < 1) return 'عدد القطع يجب أن يكون 1 على الأقل.';
    if (weight <= 0) return 'الوزن يجب أن يكون أكبر من 0.';
    if (status === 'Cancelled' && !cancellationReason.trim()) {
      return 'يرجى إدخال سبب الإلغاء.';
    }

    return null;
  };

  // Save Record handler
  const saveLabel = async (nextAction: 'list' | 'print' | 'create_another') => {
    const errorMsg = validateForm();
    if (errorMsg) {
      showToast(errorMsg, 'warning');
      return;
    }

    setLoading(true);

    try {
      const labelData: any = {
        customer_name: customerName.trim(),
        primary_phone: primaryPhone.trim(),
        secondary_phone: secondaryPhone.trim() || null,
        governorate,
        city: city.trim(),
        address: address.trim(),
        landmark: landmark.trim() || null,
        product_name: productName.trim() || null,
        contents: contents.trim(),
        pieces,
        weight,
        cod_amount: Number(codAmount),
        shipping_fee: Number(shippingFee),
        payment_method: paymentMethod,
        instructions: instructions.trim() || null,
        internal_notes: internalNotes.trim() || null,
        status,
        cancellation_reason: status === 'Cancelled' ? cancellationReason.trim() : null,
        cancelled_at: status === 'Cancelled' ? (originalCancelledAt || new Date().toISOString()) : null,
        updated_at: new Date().toISOString()
      };

      let resultId = id;

      if (isEditMode) {
        const { error } = await supabase
          .from('labels')
          .update(labelData)
          .eq('id', id);

        if (error) throw error;
        showToast('تم تحديث البوليصة بنجاح.', 'success');
      } else {
        const trackingNum = generateTrackingNumber();
        labelData.tracking_number = trackingNum;
        labelData.shipper_id = storeConfig.shipper_id;
        labelData.store_name = storeConfig.store_name;
        labelData.product_type = storeConfig.default_product_type;
        labelData.created_by = user?.id || null;
        labelData.is_printed = false;

        const { data, error } = await supabase
          .from('labels')
          .insert(labelData)
          .select()
          .single();

        if (error) throw error;
        resultId = data.id;
        showToast('تم إنشاء البوليصة بنجاح.', 'success');
      }

      // Handlers for redirect actions
      if (nextAction === 'list') {
        navigate('/labels');
      } else if (nextAction === 'print') {
        // Redirect to print layout page with the generated label selected
        navigate('/labels/batch', { state: { selectedIds: [resultId] } });
      } else if (nextAction === 'create_another') {
        // Clear all form inputs except defaults
        setCustomerName('');
        setPrimaryPhone('');
        setSecondaryPhone('');
        setGovernorate('');
        setCity('');
        setAddress('');
        setLandmark('');
        setProductName('');
        setCodAmount('');
        setInstructions('');
        setInternalNotes('');
        setContents('جراب هاتف فلكون');
        setPieces(storeConfig.default_pieces || 1);
        setWeight(storeConfig.default_weight || 1.0);
        setShippingFee(0);
        setStatus('Ready');
        setCancellationReason('');
        setOriginalCancelledAt(null);
      }

    } catch (err: any) {
      console.error(err);
      showToast(err.message || 'حدث خطأ أثناء حفظ البوليصة. يرجى المحاولة مرة أخرى.', 'error');
    } finally {
      setLoading(false);
    }
  };

  if (fetchingData) {
    return (
      <div className="p-10 flex flex-col items-center justify-center min-h-[500px]">
        <div className="w-12 h-12 border-4 border-falcon-navy border-t-transparent rounded-full animate-spin mb-4"></div>
        <span className="text-sm font-bold text-slate-500">جاري تحميل بيانات البوليصة...</span>
      </div>
    );
  }

  return (
    <div className="p-6 max-w-7xl mx-auto space-y-6">
      
      {/* Header */}
      <div className="flex items-center gap-4 bg-white p-5 rounded-2xl border border-slate-100 shadow-sm">
        <button 
          onClick={() => navigate(-1)} 
          className="p-2 hover:bg-slate-50 rounded-xl transition-colors border border-slate-100 cursor-pointer"
        >
          <ArrowRight size={18} className="text-slate-600" />
        </button>
        <div>
          <h1 className="text-xl font-bold text-slate-800">
            {isEditMode ? 'تعديل بوليصة شحن' : 'إنشاء بوليصة شحن جديدة'}
          </h1>
          <p className="text-xs text-slate-400 font-semibold mt-0.5">
            {isEditMode ? 'قم بتعديل بيانات العميل أو الطلب ثم احفظ التغييرات.' : 'أدخل بيانات العميل وتفاصيل الشحنة والتحصيل المالي لإنشاء بوليصة جديدة.'}
          </p>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
        
        {/* Form Container */}
        <div className="lg:col-span-8 bg-white rounded-2xl border border-slate-100 shadow-sm p-6">
        
        {/* Customer Section */}
        <div>
          <h2 className="text-sm font-extrabold text-falcon-navy border-r-4 border-falcon-orange pr-3 mb-5">بيانات العميل والتوصيل</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
            <div>
              <label className="block text-xs font-bold text-slate-500 mb-1.5">اسم العميل <span className="text-red-500">*</span></label>
              <input
                type="text"
                placeholder="أدخل الاسم الثنائي أو الثلاثي للعميل"
                value={customerName}
                onChange={(e) => setCustomerName(e.target.value)}
                className="w-full px-4 py-2.5 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:border-falcon-navy focus:bg-white transition-all font-semibold"
                required
              />
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div>
                <label className="block text-xs font-bold text-slate-500 mb-1.5">رقم الهاتف الأساسي <span className="text-red-500">*</span></label>
                <input
                  type="text"
                  placeholder="01xxxxxxxxx"
                  value={primaryPhone}
                  onChange={(e) => setPrimaryPhone(e.target.value)}
                  className="w-full px-4 py-2.5 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:border-falcon-navy focus:bg-white transition-all font-semibold text-left"
                  style={{ direction: 'ltr' }}
                  maxLength={11}
                  required
                />
              </div>
              <div>
                <label className="block text-xs font-bold text-slate-500 mb-1.5">رقم هاتف إضافي</label>
                <input
                  type="text"
                  placeholder="01xxxxxxxxx (اختياري)"
                  value={secondaryPhone}
                  onChange={(e) => setSecondaryPhone(e.target.value)}
                  className="w-full px-4 py-2.5 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:border-falcon-navy focus:bg-white transition-all font-semibold text-left"
                  style={{ direction: 'ltr' }}
                  maxLength={11}
                />
              </div>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div>
                <label className="block text-xs font-bold text-slate-500 mb-1.5">المحافظة <span className="text-red-500">*</span></label>
                <select
                  value={governorate}
                  onChange={(e) => handleGovernorateChange(e.target.value)}
                  className="w-full px-4 py-2.5 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:border-falcon-navy focus:bg-white transition-all font-bold"
                  required
                >
                  <option value="">اختر المحافظة</option>
                  {governorates.map((g) => (
                    <option key={g.id} value={g.governorate}>{g.governorate}</option>
                  ))}
                </select>
              </div>
              <div>
                <label className="block text-xs font-bold text-slate-500 mb-1.5">المدينة / المركز / المنطقة <span className="text-red-500">*</span></label>
                <input
                  type="text"
                  placeholder="مثال: سموحة، مصر الجديدة، الزقازيق"
                  value={city}
                  onChange={(e) => setCity(e.target.value)}
                  className="w-full px-4 py-2.5 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:border-falcon-navy focus:bg-white transition-all font-semibold"
                  required
                />
              </div>
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-500 mb-1.5">العنوان بالتفصيل <span className="text-red-500">*</span></label>
              <input
                type="text"
                placeholder="اسم الشارع، رقم العمارة، رقم الشقة/الدور"
                value={address}
                onChange={(e) => setAddress(e.target.value)}
                className="w-full px-4 py-2.5 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:border-falcon-navy focus:bg-white transition-all font-semibold"
                required
              />
            </div>

            <div className="md:col-span-2">
              <label className="block text-xs font-bold text-slate-500 mb-1.5">أقرب علامة مميزة (اختياري)</label>
              <input
                type="text"
                placeholder="بجوار مدرسة، أمام صيدلية، عمارة بنك مصر"
                value={landmark}
                onChange={(e) => setLandmark(e.target.value)}
                className="w-full px-4 py-2.5 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:border-falcon-navy focus:bg-white transition-all font-semibold"
              />
            </div>
          </div>
        </div>

        <hr className="my-8 border-slate-100" />

        {/* Product & COD Section */}
        <div>
          <h2 className="text-sm font-extrabold text-falcon-navy border-r-4 border-falcon-orange pr-3 mb-5">تفاصيل الشحنة والتحصيل</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
            <div>
              <label className="block text-xs font-bold text-slate-500 mb-1.5">اسم المنتج / كود الموديل</label>
              <input
                type="text"
                placeholder="جراب هاتف آيفون 15 مغناطيسي"
                value={productName}
                onChange={(e) => setProductName(e.target.value)}
                className="w-full px-4 py-2.5 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:border-falcon-navy focus:bg-white transition-all font-semibold"
              />
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-500 mb-1.5">محتويات الشحنة الدقيقة <span className="text-red-500">*</span></label>
              <input
                type="text"
                placeholder="عدد 1 جراب جلد بني + هدية"
                value={contents}
                onChange={(e) => setContents(e.target.value)}
                className="w-full px-4 py-2.5 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:border-falcon-navy focus:bg-white transition-all font-semibold"
                required
              />
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-xs font-bold text-slate-500 mb-1.5">عدد القطع</label>
                <input
                  type="number"
                  min={1}
                  value={pieces}
                  onChange={(e) => setPieces(Math.max(1, parseInt(e.target.value) || 1))}
                  className="w-full px-4 py-2.5 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:border-falcon-navy focus:bg-white transition-all font-bold"
                  required
                />
              </div>
              <div>
                <label className="block text-xs font-bold text-slate-500 mb-1.5">الوزن (كيلوجرام)</label>
                <input
                  type="number"
                  step={0.1}
                  min={0.1}
                  value={weight}
                  onChange={(e) => setWeight(Math.max(0.1, parseFloat(e.target.value) || 1.0))}
                  className="w-full px-4 py-2.5 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:border-falcon-navy focus:bg-white transition-all font-bold"
                  required
                />
              </div>
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-xs font-bold text-slate-500 mb-1.5">مبلغ تحصيل COD <span className="text-red-500">*</span></label>
                <input
                  type="number"
                  min={0}
                  placeholder="المبلغ المطلوب تحصيله"
                  value={codAmount}
                  onChange={(e) => setCodAmount(e.target.value === '' ? '' : Math.max(0, parseInt(e.target.value) || 0))}
                  className="w-full px-4 py-2.5 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:border-falcon-navy focus:bg-white transition-all font-bold"
                  required
                />
              </div>
              <div>
                <label className="block text-xs font-bold text-slate-500 mb-1.5">مصاريف الشحن (تلقائي)</label>
                <input
                  type="number"
                  min={0}
                  value={shippingFee}
                  onChange={(e) => setShippingFee(Math.max(0, parseInt(e.target.value) || 0))}
                  className="w-full px-4 py-2.5 text-xs bg-white border border-slate-200 rounded-xl focus:outline-none focus:border-falcon-navy font-bold text-slate-800"
                />
              </div>
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-500 mb-1.5">طريقة الدفع</label>
              <select
                value={paymentMethod}
                onChange={(e) => setPaymentMethod(e.target.value)}
                className="w-full px-4 py-2.5 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:border-falcon-navy focus:bg-white transition-all font-bold"
              >
                <option value="COD">الدفع عند الاستلام (COD)</option>
                <option value="Paid">مدفوع بالكامل مقدماً</option>
                <option value="Partial Deposit">مقدم جزئي + تحصيل الباقي</option>
              </select>
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-500 mb-1.5">حالة البوليصة</label>
              <select
                value={status}
                onChange={(e) => setStatus(e.target.value)}
                className="w-full px-4 py-2.5 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:border-falcon-navy focus:bg-white transition-all font-bold"
              >
                <option value="Ready">جاهز للطباعة والشحن</option>
                <option value="Draft">مسودة (غير جاهز)</option>
                <option value="Printed">تمت الطباعة</option>
                <option value="Cancelled">ملغي</option>
              </select>
            </div>

            {status === 'Cancelled' && (
              <div className="md:col-span-2 animate-fade-in">
                <label className="block text-xs font-bold text-red-500 mb-1.5">سبب الإلغاء <span className="text-red-500">*</span></label>
                <textarea
                  placeholder="يرجى كتابة سبب إلغاء الشحنة بالتفصيل لتوثيقه..."
                  value={cancellationReason}
                  onChange={(e) => setCancellationReason(e.target.value)}
                  rows={2}
                  className="w-full px-4 py-2.5 text-xs bg-red-50/10 border border-red-200 rounded-xl focus:outline-none focus:border-red-500 focus:bg-white transition-all font-semibold"
                  required
                />
              </div>
            )}

            <div className="md:col-span-2">
              <label className="block text-xs font-bold text-slate-500 mb-1.5">تعليمات مطبوعة للمندوب (تظهر على البوليصة)</label>
              <textarea
                placeholder="مثال: يرجى الاتصال قبل التسليم بنصف ساعة. يسمح بفتح الشحنة للمعاينة."
                value={instructions}
                onChange={(e) => setInstructions(e.target.value)}
                rows={2}
                className="w-full px-4 py-2.5 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:border-falcon-navy focus:bg-white transition-all font-semibold"
              />
            </div>

            <div className="md:col-span-2">
              <label className="block text-xs font-bold text-slate-500 mb-1.5">ملاحظات داخلية للمكتب (لا تظهر على البوليصة)</label>
              <textarea
                placeholder="تنبيهات للموظفين: مشكلة سابقة مع العميل، تحويل الحساب فودافون كاش كود رقم..."
                value={internalNotes}
                onChange={(e) => setInternalNotes(e.target.value)}
                rows={2}
                className="w-full px-4 py-2.5 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:border-falcon-navy focus:bg-white transition-all font-semibold"
              />
            </div>
          </div>
        </div>

        {/* Form Actions Footer */}
        <div className="mt-8 pt-6 border-t border-slate-100 flex flex-col sm:flex-row sm:items-center justify-end gap-3">
          <button
            type="button"
            disabled={loading}
            onClick={() => saveLabel('list')}
            className="flex items-center justify-center gap-2 px-5 py-3 border border-slate-200 hover:bg-slate-50 text-slate-700 rounded-xl font-bold text-xs transition-all disabled:opacity-50 cursor-pointer"
          >
            <Save size={16} />
            <span>حفظ والعودة للقائمة</span>
          </button>

          {!isEditMode && (
            <button
              type="button"
              disabled={loading}
              onClick={() => saveLabel('create_another')}
              className="flex items-center justify-center gap-2 px-5 py-3 border border-falcon-navy hover:bg-slate-50 text-falcon-navy rounded-xl font-bold text-xs transition-all disabled:opacity-50 cursor-pointer"
            >
              <PlusCircle size={16} />
              <span>حفظ وإنشاء بوليصة أخرى</span>
            </button>
          )}

          <button
            type="button"
            disabled={loading}
            onClick={() => saveLabel('print')}
            className="flex items-center justify-center gap-2 px-6 py-3 bg-falcon-navy hover:bg-falcon-blue text-white rounded-xl font-bold text-xs transition-all shadow-md hover:shadow-lg disabled:opacity-50 cursor-pointer"
          >
            <Printer size={16} />
            <span>{isEditMode ? 'حفظ وطباعة البوليصة' : 'حفظ وطباعة البوليصة فوراً'}</span>
          </button>
        </div>

        </div>

        {/* Live Preview Sidebar Container */}
        <div className="lg:col-span-4 lg:sticky lg:top-6 space-y-4 no-print">
          <div className="bg-falcon-navy text-white px-5 py-4 rounded-t-2xl flex items-center gap-2 shadow-sm">
            <Eye size={16} className="text-falcon-orange animate-pulse" />
            <span className="text-xs font-bold font-sans">
              معاينة البوليصة المباشرة (Live Preview)
            </span>
          </div>
          
          <div className="bg-white p-6 rounded-b-2xl border border-slate-100 border-t-0 shadow-sm flex justify-center h-[280px] overflow-hidden relative">
            <div className="scale-[0.45] sm:scale-[0.52] lg:scale-[0.45] xl:scale-[0.54] origin-top transition-all duration-200 absolute top-6">
              <WaybillLabel 
                label={{
                  tracking_number: isEditMode ? (trackingNumber || 'FLC20260600000') : 'FLCXXXXXXXXXXXX',
                  customer_name: customerName || 'اسم العميل يظهر هنا',
                  primary_phone: primaryPhone || '01000000000',
                  secondary_phone: secondaryPhone || undefined,
                  governorate: governorate || 'القاهرة',
                  city: city || 'المدينة/المركز',
                  address: address || 'تفاصيل العنوان بالتفصيل هنا',
                  landmark: landmark || undefined,
                  contents: contents || 'محتوى الشحنة',
                  pieces: pieces || 1,
                  weight: weight || 1.0,
                  cod_amount: Number(codAmount || 0),
                  shipping_fee: Number(shippingFee || 0),
                  payment_method: paymentMethod,
                  instructions: instructions || undefined,
                  shipper_id: storeConfig.shipper_id || '6525',
                  store_name: storeConfig.store_name || 'Falcon store',
                  product_type: storeConfig.default_product_type || 'COD',
                  created_at: new Date().toISOString()
                }}
                layout="3"
              />
            </div>
          </div>
        </div>

      </div>
    </div>
  );
};
