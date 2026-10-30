-- PHILIPE BARBER: disponibilidad pública y bloqueo de horarios duplicados
-- Ejecutar una sola vez en Supabase > SQL Editor.

-- La agenda usa espacios de 50 minutos. Este índice impide que dos reservas
-- activas ocupen exactamente el mismo espacio, tanto desde la web como desde el panel.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.citas
    WHERE lower(coalesce(estado, '')) NOT IN ('cancelada', 'cancelado')
    GROUP BY fecha, hora
    HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION 'Hay citas activas duplicadas con la misma fecha y hora. Revisa esas citas antes de activar el bloqueo.';
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS citas_fecha_hora_activas_uidx
ON public.citas (fecha, hora)
WHERE lower(coalesce(estado, '')) NOT IN ('cancelada', 'cancelado');

-- RPC pública que solo devuelve fecha y hora ocupadas (nunca datos personales).
CREATE OR REPLACE FUNCTION public.horarios_ocupados(p_fecha date)
RETURNS TABLE (fecha date, hora text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $function$
  SELECT c.fecha::date, left(c.hora::text, 5)
  FROM public.citas AS c
  WHERE c.fecha::date = p_fecha
    AND lower(coalesce(c.estado, '')) NOT IN ('cancelada', 'cancelado')
  ORDER BY c.hora;
$function$;

REVOKE ALL ON FUNCTION public.horarios_ocupados(date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.horarios_ocupados(date) TO anon, authenticated;

