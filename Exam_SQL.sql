
--Приложение №1 к итоговой работе "SQL и получение данных"
--Список SQL-запросов с описанием логики их выполнения.

--Вопрос №1. В каких городах больше одного аэропорта?

select ad.city ->> 'en' as "Город", count (*) as "Количество аэропортов"
from airports_data ad   -- из таблицы airports_data выбираем города, считаем количество 
group by ad.city        -- при этом группируем по городам
having  count (*) > 1   -- и выбираем те строчки, где количество больше одного 



--Вопрос №2. В каких аэропортах есть рейсы, выполняемые самолетом с максимальной дальностью перелета?
--использовать подзапрос

select ad.airport_code as "Код аэропорта"   -- выбираем код аэропорта
from airports_data ad                       -- из таблицы  airports_data             
join flights f on f.departure_airport = ad.airport_code   -- тк дальность перелета (range) хранится в таблице aircrafts_data
join aircrafts_data ad2 on ad2.aircraft_code = f.aircraft_code -- необходимо до этих данных добраться, сначала присоединяем таблицу flights, затем aircrafts_data
where ad2."range" = (        -- условие для вывода тех аэропортов, в которых есть рейсы, выполняемые самолетом с максимальной дальностью
     select max (ad2."range")       -- подзапрос возвращает максимальную дальность перелета (км)
     from aircrafts_data ad2        -- самолета из всех моделей самолетов
     )
group by ad.airport_code            -- группируем, чтобы убрать дубликаты



--Вопрос №3. Вывести 10 рейсов с максимальным временем задержки вылета
--использовать оператор LIMIT

select f.flight_no as "Номер рейса",          -- выбираем номер рейса и разность между фактическим временем вылета   
       (actual_departure - scheduled_departure) as "Время задержки рейса"   -- и временем вылета по расписанию
from flights f                                -- из таблицы flights
where (actual_departure - scheduled_departure) is not null   -- по условию, что разность не равна null 
order by (actual_departure - scheduled_departure) desc       -- сортируем в порядке убывания
limit 10                                                     -- выводим 10 рейсов



--Вопрос №4. Были ли брони, по которым не были получены посадочные талоны?
--использовать верный тип JOIN


select count(*)     -- выводим количество броней                         
from bookings b     -- из таблицы bookings
left join tickets t on t.book_ref = b.book_ref    -- присоединяем таблицу tickets оператором left join, чтобы выбрать все билеты
left join boarding_passes bp on  t.ticket_no = bp.ticket_no    -- тк в одной брони может быть несколько билетов, аналогично присоединяем таблицу  boarding_passes
where bp.boarding_no is null   -- условие, считаем те брони, где номер посадочного null (отсутствует)                         

-- аналогично для уникальных броней
select  count (distinct b.book_ref) 
from bookings b 
left join tickets t on t.book_ref = b.book_ref 
left join boarding_passes bp on  t.ticket_no = bp.ticket_no 
where bp.boarding_no is null 



--Вопрос №5. Найдите свободные места для каждого рейса, их % отношение к общему количеству мест в самолете.
--Добавьте столбец с накопительным итогом - суммарное накопление количества вывезенных пассажиров
--из каждого аэропорта на каждый день. 
--Т.е. в этом столбце должна отражаться накопительная сумма - сколько человек уже вылетело
--из данного аэропорта на этом или более ранних рейсах за день.
--! использовать оконную функцию и подзапросы/cte




-- Разбиваю задачу на подзадачи
	-- для каждой модели самолета нахожу количество мест 
	select s.aircraft_code, count(*) as "Кол-во мест"
	from seats s 
	group by s.aircraft_code 


	-- для каждого перелета нахожу количество занятых мест 
	select flight_id,  count(boarding_no) as "Занятые места" 
	from boarding_passes bp 
	group by flight_id  
	order by flight_id 

-- нахожу свободные места для каждого рейса
select f.flight_id, total - occupat 
from flights f 
join (select aircraft_code, count(seat_no) as total from seats s group by aircraft_code) as c1 on c1.aircraft_code = f.aircraft_code 
join (select flight_id,  count(boarding_no) as occupat  from boarding_passes bp group by flight_id  order by flight_id) as c2 on c2.flight_id = f.flight_id 



-- добавляю столбец с процентным соотношением, добавляю еще столбец (оконную функцию для подсчета суммы нарастающим итогом)
select f.flight_id, total - occupat as "Свободные места", ((total - occupat) *100/total) as "% от общего", 
	c2.occupat as "Вывезенные пассажиры", sum(sum(c2.occupat)) over (partition by f.actual_departure::date, f.departure_airport  order by f.actual_departure) as "Сумма нарастающим итогом "
from flights f 
join (select aircraft_code, count(seat_no) as total from seats s group by aircraft_code) as c1 on c1.aircraft_code = f.aircraft_code 
join (select flight_id,  count(boarding_no) as occupat  from boarding_passes bp group by flight_id  order by flight_id) as c2 on c2.flight_id = f.flight_id 
group by f.flight_id, c1.total, c2.occupat



--Вопрос №6. Найдите процентное соотношение перелетов по типам самолетов от общего количества.
--использовать подзапрос, оператор ROUND

select ad.aircraft_code, round (count(f.flight_id) *100 / 
                               (select count(flight_id) from flights)::numeric, 0)  --подзапрос выдает общее количество перелетов 
from aircrafts_data ad 
join flights f on f.aircraft_code = ad.aircraft_code  -- присоединяем таблицу flights, чтобы найти количество перелетов
group by ad.aircraft_code       -- группируем по моделям самолетов 



--Вопрос №7. Были ли города, в которые можно  добраться бизнес - классом дешевле,
--чем эконом-классом в рамках перелета?
--использовать СТЕ или подзапрос


with cte_1 as                             -- первый подзапрос выводит таблицу перелетов и стоимость 
      (select flight_id, amount           -- в экономическом классе
      from ticket_flights tf
      where fare_conditions = 'Economy'
      group by flight_id, amount
      ), 
cte_2 as                                  -- второй подзапрос выводит таблицу перелетов и стоимость
      (select flight_id, amount           -- в бизнес классе
      from ticket_flights tf
      where fare_conditions = 'Business' 
      group by flight_id, amount 
      )
select ad.city                                   -- выбираем города
from cte_1 c1                                    -- из подзапроса 1
join cte_2 c2 on c1.flight_id = c2.flight_id     -- соединяем с подзапросом 2 по flight_id
join flights fl on c2.flight_id = fl.flight_id 
join airports_data ad on fl.arrival_airport = ad.airport_code   -- последовательно добираемся до таблицы airports_data, где хранятся данные о городах
where c1.amount > c2.amount                      -- указываем условие, что стоимость билета из подзапроса 1 должна быть больше стоимости из подзапроса 2



--Вопрос №8. Между какими городами нет прямых рейсов?
--Декартово произведение в предложении FROM
--Самостоятельно созданные представления (если облачное подключение, то без представления)
--Оператор EXCEPT


select ad.city ->> 'ru' as "Город 1", ad2.city ->> 'ru' as "Город 2"
from airports_data ad, airports_data ad2   --соединяю два раза таблицу с городами, 
                                           --чтобы посмотреть все комбинации городов
where ad.city <> ad2.city                  --убираю одинаковые  
except                                     --вычитаю из всех комбинаций городов таблицу с прямыми рейсами 
select  ad.city ->> 'ru' as "Город 1", ad2.city ->> 'ru' as "Город 2"
from airports_data ad
join flights f on ad.airport_code =f.departure_airport   --откуда летит
join airports_data ad2 on ad2.airport_code =f.arrival_airport    --куда прилетает



--Вопрос №9. Вычислите расстояние между аэропортами, связанными прямыми рейсами,
--сравните с допустимой максимальной дальностью перелетов  в самолетах, обслуживающих эти рейсы. 


 
select ad.airport_name ->> 'ru' as "Город 1" , ad2.airport_name ->> 'ru' as "Город 2",
       ad3.model ->> 'en' as "Модель самолета",  ad3."range" as "Дальность", 
       round (acos (sin(radians(ad.coordinates[1]))*sin(radians(ad2.coordinates[1])) + cos(radians(ad.coordinates[1]))*cos(radians(ad2.coordinates[1]))*cos(radians(ad.coordinates[0]) - radians(ad2.coordinates[0]))) * 6371 ) as "Расстояние между городами",
       (ad3."range" - round (acos (sin(radians(ad.coordinates[1]))*sin(radians(ad2.coordinates[1])) + cos(radians(ad.coordinates[1]))*cos(radians(ad2.coordinates[1]))*cos(radians(ad.coordinates[0]) - radians(ad2.coordinates[0]))) * 6371 )) as "Дельта"
from airports_data ad
join flights f on ad.airport_code =f.departure_airport   --откуда летит
join airports_data ad2 on ad2.airport_code =f.arrival_airport    --куда прилетает
join aircrafts_data ad3 on ad3.aircraft_code = f.aircraft_code   --присоединяем, чтобы узнать дальность моделей
group by ad.airport_name, ad2.airport_name, ad3.model, ad3."range", ad.coordinates [0], ad2.coordinates [0], ad.coordinates [1], ad2.coordinates [1]





