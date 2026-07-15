import React, { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useToast } from '../context/ToastContext';
import { Settings as SettingsIcon, Map, Save, ShieldAlert } from 'lucide-react';

export const Settings: React.FC = () => {
  const { hasPermission } = useAuth();
  const { showToast } = useToast();

  const isAdmin = hasPermission('shipping_settings.manage');

  const [loading, setLoading] = useState(true);
  const [saveLoading, setSaveLoading] = useState(false);
  
  // Store Config state
  const [configId, setConfigId] = useState('');
  const [storeName, setStoreName] = useState('Falcon store');
  const [shipperId, setShipperId] = useState('6525');
  const [defaultProductType, setDefaultProductType] = useState('COD');
  const [defaultWeight, setDefaultWeight] = useState(1.0);
  const [defaultPieces, setDefaultPieces] = useState(1);
  const [defaultLayout, setDefaultLayout] = useState('3');
  const [businessPhone, setBusinessPhone] = useState('');
  const [barcodePrefix, setBarcodePrefix] = useState('FLC');
  const [footerNote, setFooterNote] = useState('');

  // Governorate fees state
  const [governorates, setGovernorates] = useState<any[]>([]);
  const [feesChanges, setFeesChanges] = useState<{ [id: string]: number }>({});

  const fetchSettings = async () => {
    try {
      setLoading(true);
      
      // Load store config
      const { data: configData } = await supabase
        .from('shipping_settings')
        .select('*')
        .eq('key', 'store_config')
        .single();

      if (configData) {
        setConfigId(configData.id);
        const config = configData.value as unknown as {
          store_name?: string; shipper_id?: string; default_product_type?: string;
          default_weight?: number; default_pieces?: number; default_layout?: string;
          business_phone?: string; barcode_prefix?: string; footer_note?: string;
        };
        setStoreName(config.store_name || 'Falcon store');
        setShipperId(config.shipper_id || '6525');
        setDefaultProductType(config.default_product_type || 'COD');
        setDefaultWeight(Number(config.default_weight || 1.0));
        setDefaultPieces(Number(config.default_pieces || 1));
        setDefaultLayout(config.default_layout || '3');
        setBusinessPhone(config.business_phone || '');
        setBarcodePrefix(config.barcode_prefix || 'FLC');
        setFooterNote(config.footer_note || '');
      }

      // Load governorate fees
      const { data: govData } = await supabase
        .from('governorate_shipping_fees')
        .select('*')
        .order('governorate', { ascending: true });

      if (govData) {
        setGovernorates(govData);
      }

    } catch (e) {
      console.error(e);
      showToast('خطأ في تحميل الإعدادات.', 'error');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchSettings();
  }, []);

  const handleSaveStoreConfig = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!isAdmin) {
      showToast('عذراً، فقط مدير النظام (Admin) يمتلك صلاحية تعديل الإعدادات.', 'error');
      return;
    }

    try {
      setSaveLoading(true);
      const updatedConfigValue = {
        store_name: storeName,
        shipper_id: shipperId,
        default_product_type: defaultProductType,
        default_weight: Number(defaultWeight),
        default_pieces: Number(defaultPieces),
        default_layout: defaultLayout,
        business_phone: businessPhone,
        barcode_prefix: barcodePrefix,
        footer_note: footerNote
      };

      const { error } = await supabase
        .from('shipping_settings')
        .upsert({
          id: configId || undefined,
          key: 'store_config',
          value: updatedConfigValue,
          updated_at: new Date().toISOString()
        });

      if (error) throw error;
      showToast('تم حفظ إعدادات المتجر بنجاح.', 'success');
    } catch (e: any) {
      console.error(e);
      showToast(e.message || 'خطأ أثناء حفظ الإعدادات.', 'error');
    } finally {
      setSaveLoading(false);
    }
  };

  const handleFeeChange = (id: string, value: string) => {
    const numericVal = Math.max(0, parseInt(value) || 0);
    setFeesChanges(prev => ({ ...prev, [id]: numericVal }));
  };

  const handleSaveFees = async () => {
    if (!isAdmin) {
      showToast('عذراً، فقط مدير النظام (Admin) يمتلك صلاحية تعديل الإعدادات.', 'error');
      return;
    }

    const changeKeys = Object.keys(feesChanges);
    if (changeKeys.length === 0) {
      showToast('لم تقم بإجراء أي تغييرات على مصاريف الشحن لتعديلها.', 'warning');
      return;
    }

    try {
      setSaveLoading(true);

      // Prepare batch updates data
      const upsertData = changeKeys.map(id => {
        const govItem = governorates.find(g => g.id === id);
        return {
          id: id,
          governorate: govItem.governorate,
          shipping_fee: feesChanges[id]
        };
      });

      // Execute bulk upsert in a single network request
      const { error } = await supabase
        .from('governorate_shipping_fees')
        .upsert(upsertData);
      
      if (error) throw error;

      showToast('تم تحديث مصاريف شحن المحافظات بنجاح.', 'success');
      setFeesChanges({});
      fetchSettings();
    } catch (e: any) {
      console.error(e);
      showToast(e.message || 'خطأ أثناء تحديث مصاريف الشحن.', 'error');
    } finally {
      setSaveLoading(false);
    }
  };

  if (loading) {
    return (
      <div className="p-10 flex flex-col items-center justify-center min-h-[500px]">
        <div className="w-12 h-12 border-4 border-falcon-navy border-t-transparent rounded-full animate-spin mb-4"></div>
        <span className="text-sm font-bold text-slate-500">جاري تحميل إعدادات النظام...</span>
      </div>
    );
  }

  return (
    <div className="p-6 space-y-6 max-w-5xl mx-auto">
      
      {/* Title */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 bg-white p-5 rounded-2xl border border-slate-100 shadow-sm">
        <div className="flex items-center gap-3">
          <div className="p-2 bg-slate-100 text-falcon-navy rounded-xl border border-slate-200">
            <SettingsIcon size={22} />
          </div>
          <div>
            <h1 className="text-xl font-bold text-slate-800">إعدادات النظام</h1>
            <p className="text-xs text-slate-400 font-semibold mt-0.5">اضبط إعدادات الشحن، قيم التحصيل الافتراضية، ومصاريف الشحن لكل محافظة.</p>
          </div>
        </div>
      </div>

      {/* Staff Read-Only Warning */}
      {!isAdmin && (
        <div className="bg-amber-50 border border-amber-200 p-4 rounded-xl flex items-start gap-3">
          <ShieldAlert className="text-amber-600 mt-0.5 shrink-0" size={18} />
          <div>
            <h4 className="text-xs font-black text-amber-900">وضع القراءة فقط للموظفين</h4>
            <p className="text-[11px] text-amber-800 font-bold mt-1 leading-relaxed">
              حسابك الحالي مسجل بصلاحية (موظف شحن). يمكنك استعراض الإعدادات ومصاريف الشحن الحالية للمحافظات، ولكن لا يمكنك تعديلها أو حفظها. يرجى التواصل مع مدير النظام لتعديل هذه القيم.
            </p>
          </div>
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        
        {/* Store Config Form (7 Cols) */}
        <div className="lg:col-span-7 bg-white rounded-2xl border border-slate-100 shadow-sm p-6 space-y-5">
          <div className="flex items-center gap-2 pb-3 border-b border-slate-100 text-slate-800">
            <SettingsIcon size={16} />
            <h2 className="text-sm font-extrabold">بيانات بوليصة الشحن الافتراضية</h2>
          </div>

          <form onSubmit={handleSaveStoreConfig} className="space-y-4">
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label className="block text-xs font-bold text-slate-500 mb-1.5">اسم المتجر (الراسل)</label>
                <input
                  type="text"
                  value={storeName}
                  onChange={(e) => setStoreName(e.target.value)}
                  className="w-full px-4 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:border-falcon-navy focus:bg-white font-semibold"
                  disabled={!isAdmin}
                  required
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-500 mb-1.5">رقم الراسل (Shipper ID)</label>
                <input
                  type="text"
                  value={shipperId}
                  onChange={(e) => setShipperId(e.target.value)}
                  className="w-full px-4 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:border-falcon-navy focus:bg-white font-semibold"
                  disabled={!isAdmin}
                  required
                />
              </div>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
              <div>
                <label className="block text-xs font-bold text-slate-500 mb-1.5">نوع المنتج الافتراضي</label>
                <input
                  type="text"
                  value={defaultProductType}
                  onChange={(e) => setDefaultProductType(e.target.value)}
                  className="w-full px-4 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:border-falcon-navy focus:bg-white font-semibold"
                  disabled={!isAdmin}
                  required
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-500 mb-1.5">الوزن الافتراضي (كجم)</label>
                <input
                  type="number"
                  step={0.1}
                  value={defaultWeight}
                  onChange={(e) => setDefaultWeight(parseFloat(e.target.value) || 1.0)}
                  className="w-full px-4 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:border-falcon-navy focus:bg-white font-bold"
                  disabled={!isAdmin}
                  required
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-500 mb-1.5">القطع الافتراضية</label>
                <input
                  type="number"
                  value={defaultPieces}
                  onChange={(e) => setDefaultPieces(parseInt(e.target.value) || 1)}
                  className="w-full px-4 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:border-falcon-navy focus:bg-white font-bold"
                  disabled={!isAdmin}
                  required
                />
              </div>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label className="block text-xs font-bold text-slate-500 mb-1.5">بادئة رقم البوليصة</label>
                <input
                  type="text"
                  value={barcodePrefix}
                  onChange={(e) => setBarcodePrefix(e.target.value)}
                  className="w-full px-4 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:border-falcon-navy focus:bg-white font-bold"
                  disabled={!isAdmin}
                  required
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-500 mb-1.5">رقم تليفون العمل</label>
                <input
                  type="text"
                  value={businessPhone}
                  onChange={(e) => setBusinessPhone(e.target.value)}
                  className="w-full px-4 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:border-falcon-navy focus:bg-white font-semibold text-left"
                  style={{ direction: 'ltr' }}
                  disabled={!isAdmin}
                />
              </div>
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-500 mb-1.5">تخطيط الطباعة الافتراضي على A4</label>
              <select
                value={defaultLayout}
                onChange={(e) => setDefaultLayout(e.target.value)}
                className="w-full px-4 py-2.5 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:border-falcon-navy font-bold"
                disabled={!isAdmin}
              >
                <option value="3">3 بوليصات في الصفحة (ارتفاع 88 مم - مقترح)</option>
                <option value="2">بوليصتان في الصفحة (ارتفاع 128 مم)</option>
              </select>
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-500 mb-1.5">ملاحظة التذييل على البوليصة (تظهر بالأسفل)</label>
              <textarea
                value={footerNote}
                onChange={(e) => setFooterNote(e.target.value)}
                rows={2}
                className="w-full px-4 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:border-falcon-navy focus:bg-white font-semibold"
                disabled={!isAdmin}
              />
            </div>

            {isAdmin && (
              <div className="pt-2 flex justify-end">
                <button
                  type="submit"
                  disabled={saveLoading}
                  className="flex items-center gap-2 px-6 py-2.5 bg-falcon-navy hover:bg-falcon-blue text-white rounded-xl font-bold text-xs shadow-md transition-all cursor-pointer"
                >
                  <Save size={16} />
                  <span>حفظ إعدادات المتجر</span>
                </button>
              </div>
            )}
          </form>
        </div>

        {/* Shipping Fees (5 Cols) */}
        <div className="lg:col-span-5 bg-white rounded-2xl border border-slate-100 shadow-sm p-6 flex flex-col justify-between">
          <div className="space-y-4">
            <div className="flex items-center gap-2 pb-3 border-b border-slate-100 text-slate-800">
              <Map size={16} />
              <h2 className="text-sm font-extrabold">تعريفة شحن المحافظات</h2>
            </div>
            
            <p className="text-[10px] text-slate-400 font-semibold leading-relaxed">
              هذه الأسعار تُستخدم لتعبئة خانة "مصاريف الشحن" تلقائياً بمجرد اختيار الموظف للمحافظة في نموذج إنشاء البوليصة.
            </p>

            <div className="overflow-y-auto max-h-[360px] border border-slate-100 rounded-xl divide-y divide-slate-100">
              {governorates.map((gov) => {
                const isChanged = feesChanges[gov.id] !== undefined;
                const currentVal = isChanged ? feesChanges[gov.id] : gov.shipping_fee;
                
                return (
                  <div key={gov.id} className="flex items-center justify-between p-3 bg-slate-50/30">
                    <span className="text-xs font-bold text-slate-700">{gov.governorate}</span>
                    <div className="flex items-center gap-2">
                      <input
                        type="number"
                        min={0}
                        value={currentVal}
                        onChange={(e) => handleFeeChange(gov.id, e.target.value)}
                        className={`w-20 px-2.5 py-1 text-xs text-center border rounded-lg focus:outline-none focus:border-falcon-navy font-bold ${isChanged ? 'border-orange-400 bg-orange-50/30' : 'border-slate-200 bg-white'}`}
                        disabled={!isAdmin}
                      />
                      <span className="text-[10px] text-slate-400 font-bold">ج.م</span>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          {isAdmin && (
            <div className="pt-4 border-t border-slate-100 mt-4 flex justify-end">
              <button
                type="button"
                onClick={handleSaveFees}
                disabled={saveLoading || Object.keys(feesChanges).length === 0}
                className="flex items-center gap-2 px-6 py-2.5 bg-falcon-navy hover:bg-falcon-blue text-white rounded-xl font-bold text-xs shadow-md transition-all disabled:opacity-50 cursor-pointer"
              >
                <Save size={16} />
                <span>حفظ مصاريف الشحن</span>
              </button>
            </div>
          )}
        </div>

      </div>

    </div>
  );
};
