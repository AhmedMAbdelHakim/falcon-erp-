import React, { useState } from 'react';
import { NavLink, useNavigate, useLocation } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useToast } from '../context/ToastContext';
import { 
  LayoutDashboard, 
  FilePlus, 
  Files, 
  FileX2, 
  Settings as SettingsIcon, 
  LogOut, 
  Menu, 
  X, 
  User,
  Database,
  WifiOff
} from 'lucide-react';

export const Sidebar: React.FC = () => {
  const { access, signOut, configured, hasRole } = useAuth();
  const { showToast } = useToast();
  const navigate = useNavigate();
  const location = useLocation();
  const [isOpen, setIsOpen] = useState(false);

  const menuItems = [
    { name: 'لوحة التحكم', path: '/', icon: LayoutDashboard },
    { name: 'إنشاء بوليصة', path: '/labels/new', icon: FilePlus },
    { name: 'قائمة البوليصات', path: '/labels', icon: Files },
    { name: 'البوليصات الملغية', path: '/cancelled', icon: FileX2 },
    { name: 'الإعدادات', path: '/settings', icon: SettingsIcon },
  ];

  const handleLogout = async () => {
    await signOut();
    showToast('تم تسجيل الخروج بنجاح.', 'success');
    navigate('/login');
  };

  const activeClass = "flex items-center gap-3 px-4 py-3 bg-falcon-navy text-white rounded-lg transition-all duration-200 shadow-md";
  const inactiveClass = "flex items-center gap-3 px-4 py-3 text-slate-600 hover:bg-slate-100 hover:text-falcon-navy rounded-lg transition-all duration-200";

  return (
    <>
      {/* Mobile Header */}
      <div className="flex items-center justify-between px-4 py-3 bg-falcon-navy text-white md:hidden no-print shadow-md">
        <div className="flex items-center gap-2">
          <span className="text-xl font-extrabold tracking-wider text-falcon-orange">فلكون / Falcon</span>
        </div>
        <button onClick={() => setIsOpen(!isOpen)} className="p-1 hover:bg-falcon-blue rounded">
          {isOpen ? <X size={24} /> : <Menu size={24} />}
        </button>
      </div>

      {/* Sidebar container */}
      <aside className={`
        fixed inset-y-0 right-0 z-40 flex flex-col justify-between w-64 bg-white border-l border-slate-200 shadow-xl transition-transform duration-300 md:translate-x-0 md:static md:z-0 no-print
        ${isOpen ? 'translate-x-0' : 'translate-x-full'}
      `}>
        <div>
          {/* Logo & Header */}
          <div className="hidden md:flex items-center justify-between px-6 py-5 border-b border-slate-100">
            <div className="flex flex-col gap-0.5">
              <span className="text-2xl font-extrabold text-falcon-navy tracking-tight">فَلْكُون</span>
              <span className="text-xs text-slate-400 font-medium tracking-widest uppercase">Falcon Shipping</span>
            </div>
            
            {/* Connection Indicator */}
            {!configured ? (
              <span className="flex items-center gap-1 px-2 py-1 text-[10px] font-semibold text-amber-700 bg-amber-50 rounded-full border border-amber-200 animate-pulse">
                <WifiOff size={10} /> local
              </span>
            ) : (
              <span className="flex items-center gap-1 px-2 py-1 text-[10px] font-semibold text-emerald-700 bg-emerald-50 rounded-full border border-emerald-200">
                <Database size={10} /> live
              </span>
            )}
          </div>

          {/* Navigation Links */}
          <nav className="p-4 space-y-1.5">
            {menuItems.map((item) => {
              const Icon = item.icon;
              const isActive = location.pathname === item.path || 
                               (item.path !== '/' && location.pathname.startsWith(item.path));
              return (
                <NavLink
                  key={item.path}
                  to={item.path}
                  onClick={() => setIsOpen(false)}
                  className={isActive ? activeClass : inactiveClass}
                >
                  <Icon size={18} />
                  <span className="font-semibold text-sm">{item.name}</span>
                </NavLink>
              );
            })}
          </nav>
        </div>

        {/* User profile & Log out */}
        <div className="p-4 border-t border-slate-100 bg-slate-50/50">
          <div className="flex items-center gap-3 px-2 py-3 mb-3">
            <div className="flex items-center justify-center w-10 h-10 rounded-full bg-slate-200 text-slate-600">
              <User size={20} />
            </div>
            <div className="flex flex-col min-w-0">
              <span className="text-sm font-bold text-slate-800 truncate">{access?.display_name || 'موظف فلكون'}</span>
              <span className="text-[11px] text-slate-400 font-semibold mt-0.5">
                {hasRole('super_admin') ? (
                  <span className="px-1.5 py-0.5 bg-red-50 text-red-600 rounded border border-red-100">مدير النظام</span>
                ) : (
                  <span className="px-1.5 py-0.5 bg-slate-100 text-slate-600 rounded border border-slate-200">موظف شحن</span>
                )}
              </span>
            </div>
          </div>

          <button
            onClick={handleLogout}
            className="flex items-center gap-3 w-full px-4 py-2.5 text-red-600 hover:bg-red-50 rounded-lg transition-colors font-semibold text-sm"
          >
            <LogOut size={16} />
            <span>تسجيل الخروج</span>
          </button>
        </div>
      </aside>

      {/* Overlay for mobile drawer */}
      {isOpen && (
        <div 
          onClick={() => setIsOpen(false)} 
          className="fixed inset-0 z-30 bg-black/40 backdrop-blur-sm md:hidden no-print"
        />
      )}
    </>
  );
};
